//
//  DVGAudioWriter.m
//  Denoise
//
//  Created by Denis Bulichenko on 18/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

#import "DVGAudioWriter.h"
#import "DVGAudioToolboxUtilities.h"
@import Darwin.AssertMacros;

static const short kDVGMaxProgressUnits = 1000;
static const NSString* kDVGExportProcess = @"exporter";
static const NSString* kDVGExportProgress = @"progress";

@interface DVGAudioWriter ()

@property (readonly, nonatomic) NSMutableData* samples;

@property (readonly, nonatomic) AudioStreamBasicDescription samplesFormat;

@property (nonatomic) NSURL* audioFileURL;
@property (nonatomic) ExtAudioFileRef outFileRef;
@property (atomic,assign) int attemptSeq;
@end


@implementation DVGAudioWriter

/**
 *  Initialize audio writer with samples of particular format
 */
- (instancetype)initWithAudioSamples:(NSMutableData *)samples ofFormat:(AudioStreamBasicDescription)samplesFormat
{
    if (self = [super init]) {
        _samples = samples;
        _samplesFormat = samplesFormat;
    }
    
    return self;
}

/*
 *  Saves PCM audio samples into an audio file
 */
//- (void)writeSamplesIntoAudioFile:(NSURL *)fileURL
//{
//    return [self writeSamplesIntoAudioFile:fileURL
//                            shouldCompress:YES
//                             softwareCodec:NO];
//}

/*
 *  Saves PCM audio samples into an audio file
 * Warning: Better to use software codec
 */
//- (void)writeSamplesIntoAudioFile:(NSURL *)fileURL
//                   shouldCompress:(BOOL)compress_with_m4a
//                    softwareCodec:(BOOL)softwareCodec
//{
//    OSStatus err;
//    
//    // Creates the audio file reference first
//    err = [self createAudioFile:fileURL
//                 shouldCompress:compress_with_m4a
//                  softwareCodec:softwareCodec];
//    __Require_noErr_String(err, exceptionLabel, "Error creating audio file");
//    
//    // Appends bytes into audio file then
//    err = [self appendBytesToAudioFile:self.samples];
//    __Require_noErr_String(err, exceptionLabel, "Error writing audio file");
//    
//exceptionLabel:
//    // Flushes all write buffers and closes the reference
//    err = [self closeAudioFile];
//}

/**
 *  Creates audio file for output
 */
- (OSStatus)createAudioFile
{
    OSStatus err;
    self.attemptSeq++;
    _audioFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f-%i.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, self.attemptSeq, @"m4a"]]];
    err = [self createAudioFile:_audioFileURL shouldCompress:YES softwareCodec:NO];
    //NSLog(@"createAudioFile: %i",_outFileRef);
    return err;
}


- (OSStatus)closeAudioFile
{
    OSStatus res = noErr;
    if (self.outFileRef) {
        //NSLog(@"closeAudioFile: %i",_outFileRef);
        res = ExtAudioFileDispose(self.outFileRef);
        self.outFileRef = nil;
    }
    return res;
}

- (BOOL)isWritingAnything {
    if(self.outFileRef){
        return YES;
    }
    return NO;
}

/**
 *  Creates audio file for output
 */
- (OSStatus)createAudioFile:(NSURL *)fileURL
             shouldCompress:(BOOL)compress_with_m4a
              softwareCodec:(BOOL)softwareCodec
{
    OSStatus err;
    
    // the client format will describe the output audio file
    AudioStreamBasicDescription clientFormat;
    
    // the file type identifier tells the ExtAudioFile API what kind of file we want created
    AudioFileTypeID fileType;
    
    // if compress_with_m4a is tru then set up for m4a file format
    if (compress_with_m4a)
    {
        // the file type identifier tells the ExtAudioFile API what kind of file we want created
        // this creates a m4a file type
        fileType = kAudioFileM4AType;
        
        // Here we specify the M4A format
        clientFormat.mSampleRate         = 44100.0;
        clientFormat.mFormatID           = kAudioFormatMPEG4AAC;
        clientFormat.mFormatFlags        = kMPEG4Object_AAC_Main;
        clientFormat.mChannelsPerFrame   = _samplesFormat.mChannelsPerFrame;
        clientFormat.mBytesPerPacket     = 0;
        clientFormat.mBytesPerFrame      = 0;
        clientFormat.mFramesPerPacket    = 1024;
        clientFormat.mBitsPerChannel     = 0;
        clientFormat.mReserved           = 0;
    } else {
        // else encode as PCM
        // this creates a wav file type
        fileType = kAudioFileWAVEType;
    }
    
    // open the file for writing
    self.outFileRef = nil;
    err = ExtAudioFileCreateWithURL((__bridge CFURLRef)fileURL,
                                    fileType,
                                    &clientFormat,
                                    NULL,
                                    kAudioFileFlags_EraseFile,
                                    &_outFileRef);
    if(err != noErr){
        NSLog(@"DVGAudioWriter: Failed to ExtAudioFileCreateWithURL: url=%@, code=%i",fileURL,err);
    }
    __Require_noErr_String(err, exceptionLabel, "Error creating audio file");
    
    if (softwareCodec) {
        UInt32 codecManf = kAppleSoftwareAudioCodecManufacturer;
        err = ExtAudioFileSetProperty(_outFileRef,
                                      kExtAudioFileProperty_CodecManufacturer,
                                      sizeof(UInt32),
                                      &codecManf);
        __Require_noErr_String(err, exceptionLabel, "Error setting softw codec manufacturer");
    }else{
        UInt32 codecManf = kAppleHardwareAudioCodecManufacturer;
        err = ExtAudioFileSetProperty(_outFileRef,
                                      kExtAudioFileProperty_CodecManufacturer,
                                      sizeof(UInt32),
                                      &codecManf);
        __Require_noErr_String(err, exceptionLabel, "Error setting hardw codec manufacturer");
    }
    
    // Tell the ExtAudioFile API what format we'll be sending samples in
    err = ExtAudioFileSetProperty(_outFileRef,
                                  kExtAudioFileProperty_ClientDataFormat,
                                  sizeof(AudioStreamBasicDescription),
                                  &_samplesFormat);
    if (err != noErr && !softwareCodec) {
        // Fallback to software codec
        [self closeAudioFile];
        return [self createAudioFile:fileURL shouldCompress:compress_with_m4a softwareCodec:YES];
    }
    __Require_noErr_String(err, exceptionLabel, "Error setting client data format");
    
exceptionLabel:
    return err;
}

/**
 *  Appends NSMutableData into the end of file
 */
- (OSStatus)appendBytesToAudioFile:(SInt16*)readySamples bytesLen:(NSInteger)len
{
    // specify total number of samples per channel
    UInt32 totalFramesInFile = ((int)(len / (_samplesFormat.mChannelsPerFrame * sizeof(SInt16))));
    UInt32 totalBytes = totalFramesInFile * sizeof(SInt16) * _samplesFormat.mChannelsPerFrame;
    SInt16* samples = malloc(totalBytes);
    memcpy(samples, readySamples, totalBytes);
    
    AudioBufferList outputData;
    outputData.mNumberBuffers = 1;
    outputData.mBuffers[0].mNumberChannels = _samplesFormat.mChannelsPerFrame;
    outputData.mBuffers[0].mDataByteSize = totalBytes;//sizeof(SInt16)*totalFramesInFile*_samplesFormat.mChannelsPerFrame;
    outputData.mBuffers[0].mData = samples;//mutableData.mutableBytes;
    
    // write the data
    OSStatus err = ExtAudioFileWriteAsync(self.outFileRef, totalFramesInFile, &outputData);
    if(err != noErr){
        NSLog(@"DVGAudioWriter: Failed to ExtAudioFileWrite: code=%i", err);
    }
    return err;
}

/**
 *  Saves audio track into video file
 */
- (NSProgress*)writeAudioIntoVideoFile:(NSURL *)videoURL fromAsset:(AVAsset*)asset completionHandler:(void (^)(BOOL completed, NSError *error))completionHandler
{
    // Create a composition for export
    AVMutableComposition *videoComposition = [AVMutableComposition composition];
    
    // Add input video
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    for (AVAssetTrack *track in videoTracks) {
        AVMutableCompositionTrack *videoCompositionTrack = [videoComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [videoCompositionTrack insertTimeRange:track.timeRange ofTrack:track atTime:track.timeRange.start error:nil];
        videoCompositionTrack.preferredTransform = track.preferredTransform;
    }
    
    // Add noise filtered audio
    /*_audioFileURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%.0f.%@", [NSDate timeIntervalSinceReferenceDate] * 1000.0, @"m4a"]]];
    [self writeSamplesIntoAudioFile:_audioFileURL shouldCompress:YES softwareCodec:YES];*/
    
    // Compose audio into video
    AVMutableCompositionTrack *audioCompositionTrack = [videoComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    AVAsset *cleanAudio = [AVAsset assetWithURL:_audioFileURL];
    AVAssetTrack *audioTrack = [[cleanAudio tracksWithMediaType:AVMediaTypeAudio] lastObject];
    [audioCompositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioTrack.timeRange.duration) ofTrack:audioTrack atTime:kCMTimeZero error:nil];
    
    // Export
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:videoComposition presetName:AVAssetExportPresetHighestQuality];
    exporter.outputFileType = AVFileTypeQuickTimeMovie;
    exporter.outputURL = videoURL;
    
    // Track export progress (up to 100.0%)
    NSProgress* progress = [NSProgress progressWithTotalUnitCount:kDVGMaxProgressUnits];
    NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                      target:self
                                                    selector:@selector(updateExportProgress:)
                                                    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                              exporter, kDVGExportProcess,
                                                              progress, kDVGExportProgress,
                                                              nil]
                                                     repeats:YES];
    
    // Start the exporting operation
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        // The exporting has been finished
        //NSLog(@"Exporting audio/video compostion has been completed");
        progress.completedUnitCount = kDVGMaxProgressUnits;
        [timer invalidate];
        switch (exporter.status) {
            case AVAssetExportSessionStatusCompleted: {
                if (completionHandler) completionHandler(YES, exporter.error);
                break;
            }
                
            case AVAssetExportSessionStatusUnknown:
            case AVAssetExportSessionStatusWaiting:
            case AVAssetExportSessionStatusExporting:
            case AVAssetExportSessionStatusFailed:
            case AVAssetExportSessionStatusCancelled: {
                if (completionHandler) completionHandler(NO, exporter.error);
                break;
            }
        }
    }];
    return progress;
}

/**
 *  Updates export progress (from 0 to 1) until the exporting is completed
 */
- (void)updateExportProgress:(NSTimer *)timer {
    NSDictionary *dict = [timer userInfo];
    AVAssetExportSession *exporter = [dict objectForKey:kDVGExportProcess];
    NSProgress* progress = [dict objectForKey:kDVGExportProgress];
    progress.completedUnitCount = kDVGMaxProgressUnits*exporter.progress;
    if (exporter.progress == 1.0) {
        progress.completedUnitCount = kDVGMaxProgressUnits;
        [timer invalidate];
    }
}


@end
