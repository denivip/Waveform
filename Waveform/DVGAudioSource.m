//
//  DVGAudioSamples.m
//  Denoise
//
//  Created by Denis Bulichenko on 17/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

#import "DVGAudioSource.h"
@import CoreMedia;
@import AVFoundation;

@interface DVGAudioSource ()

@property (nonatomic) AVAsset* asset;

@end




@implementation DVGAudioSource

/**
 * Initialize audio source with an asset
 */
- (instancetype)initWithAsset:(AVAsset *)asset
{
    if (self = [super init]) {
        _asset = asset;
    }
    
    return self;
}

/**
 *  Reads audio data and initializes internal buffers
 */
- (void)readAudioFormat:(void (^)(BOOL, NSError *))completionBlock
{
    NSError *error;
    AudioStreamBasicDescription audioFormat;
    BOOL ok = [self _readAudioFormat:&audioFormat error:&error];
    if (!ok) {
        if (completionBlock) completionBlock(NO, error);
        return;
    }
    
    _audioFormat = audioFormat;
    
    if (completionBlock) completionBlock(ok, error);
}

/**
 * Returns current asset's audio track
 */
- (AVAssetTrack *)assetAudioTrack
{
    return [[self.asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
}

/**
 * Reads audio format from the current AVAsset
 */
- (BOOL)_readAudioFormat:(AudioStreamBasicDescription *)audioFormatOut
                  error:(NSError * __autoreleasing *)errorOut
{
    AudioStreamBasicDescription audioFormat;
    
    AVAssetTrack *sound = [self assetAudioTrack];
    if (!sound) {
        if (errorOut) *errorOut = [NSError errorWithDomain:@"DVGAudioProcessorErrorDomain" code:-1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"This video does not contain sound", nil) }];
        return NO;
    }
    
    CMFormatDescriptionRef formatDescription = (__bridge CMFormatDescriptionRef)([[sound formatDescriptions] firstObject]);
    if (!formatDescription) {
        if (errorOut) *errorOut = [NSError errorWithDomain:@"DVGAudioProcessorErrorDomain" code:-1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Invalid audio format", nil) }];
        return NO;
    }
    
    NSLog(@"DEBUG Audio format description => %@", formatDescription);
    
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    
    // Configure audio stream description
    audioFormat.mSampleRate = asbd->mSampleRate;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian;
    audioFormat.mChannelsPerFrame = 2;//< Stereo;
    audioFormat.mBitsPerChannel = 8 * sizeof(SInt16);
    audioFormat.mBytesPerFrame = audioFormat.mChannelsPerFrame * sizeof(SInt16);
    audioFormat.mBytesPerPacket = audioFormat.mChannelsPerFrame * sizeof(SInt16);
    audioFormat.mFramesPerPacket = 1;//< Not compressed
    audioFormat.mReserved = 0;
    if (audioFormatOut) *audioFormatOut = audioFormat;
    
    return YES;
}

/**
 *  Reads all audio samples from the asset and returns samples sequentially via sample block
 */
- (BOOL)readAudioSamplesData:(void (^)(NSData *sampleData, BOOL *stop))sampleBlock
                       error:(NSError * __autoreleasing *)errorOut
{
    return [self readAudioSamplesIntervalData:sampleBlock timerange:CMTimeRangeMake(kCMTimeZero, _asset.duration) error:errorOut];
}

/**
 *  Reads audio samples from a particular time interval in the asset and returns samples
 *  sequentially via sample block
 */
- (BOOL)readAudioSamplesIntervalData:(void (^)(NSData *sampleData, BOOL *stop))sampleBlock
                           timerange:(CMTimeRange)timerange
                               error:(NSError * __autoreleasing *)errorOut
{
    AVAssetTrack *sound = [self assetAudioTrack];
    if (!sound) {
        if (errorOut) *errorOut = [NSError errorWithDomain:@"DVGAudioProcessorErrorDomain" code:-1 userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"This video does not contain sound", nil) }];
        return NO;
    }
    
    NSError *error;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    if (!assetReader) {
        if (errorOut) *errorOut = error;
        return NO;
    }
    
    NSDictionary *audioReadSettings = @{ AVFormatIDKey : @(kAudioFormatLinearPCM),
                                         AVSampleRateKey : @(self.audioFormat.mSampleRate),
                                         AVNumberOfChannelsKey : @(2),
                                         AVLinearPCMBitDepthKey : @(16),
                                         AVLinearPCMIsBigEndianKey : @(NO),
                                         AVLinearPCMIsFloatKey : @(NO),
                                         AVLinearPCMIsNonInterleaved : @(NO) };
    
    AVAssetReaderTrackOutput *readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:sound outputSettings:audioReadSettings];
    [assetReader addOutput:readerOutput];
    
    assetReader.timeRange = timerange;
    
    BOOL started = [assetReader startReading];
    if (!started) {
        if (errorOut) *errorOut = assetReader.error;
        return NO;
    }
    
    //NSLog(@"DEBUG Started reading audio track");
    while (assetReader.status == AVAssetReaderStatusReading) {
        @autoreleasepool {
            CMSampleBufferRef sampleBuffer = [readerOutput copyNextSampleBuffer];
            if (!sampleBuffer) continue;
            
            // Get buffer
            CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            size_t length = CMBlockBufferGetDataLength(buffer);
            NSMutableData *temporaryData = [[NSMutableData alloc] initWithLength:length];
            
            // Append new data
            char *bufferData;
            CMBlockBufferAccessDataBytes(buffer, 0, length, temporaryData.mutableBytes, &bufferData);
            NSData *data = [[NSData alloc] initWithBytesNoCopy:bufferData length:length freeWhenDone:NO];
            BOOL stop = NO;
            @autoreleasepool {
                sampleBlock(data, &stop);
            }
            
            CFRelease(sampleBuffer);
            
            if (stop) return YES;
        }
    }
    
    switch (assetReader.status) {
        case AVAssetReaderStatusUnknown:
        case AVAssetReaderStatusFailed:
        case AVAssetReaderStatusCancelled:
        case AVAssetReaderStatusReading:
            if (errorOut) *errorOut = assetReader.error;
            return NO;
            
        case AVAssetReaderStatusCompleted:
            return YES;
    }
}


@end
