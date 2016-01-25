//
//  DVGAudioWriter.h
//  Denoise
//
//  Created by Denis Bulichenko on 18/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

@import Foundation;
@import CoreMedia;
@import AVFoundation;

#define MEMSAFEWARPER 2
@interface DVGAudioWriter : NSObject

/**
 *  Initialize audio writer with samples of particular format.
 *  All consecutive samples (if any) should be in the same format.
 */
- (instancetype)initWithAudioSamples:(NSMutableData *)samples
                            ofFormat:(AudioStreamBasicDescription)samplesFormat;

/**
 *  Creates empty audio file for further samples write
 */
- (OSStatus)createAudioFile;

/**
 *  Appends NSMutableData into the end of file
 */
- (OSStatus)appendBytesToAudioFile:(SInt16*)samples bytesLen:(NSInteger)len;

/**
 *  Closes audio file
 */
- (OSStatus)closeAudioFile;


- (BOOL)isWritingAnything;

/**
 *  Saves PCM audio samples into an audio file in one operation:
 *  creates audio file and puts all samples into it.
 * Not suitable for lengthy files (due memory footprint)
 */
//- (void)writeSamplesIntoAudioFile:(NSURL *)fileURL;


/**
 *  Saves audio track into video file (AVComposition)
 */
- (NSProgress*)writeAudioIntoVideoFile:(NSURL *)videoURL
                             fromAsset:(AVAsset*)asset
                     completionHandler:(void (^)(BOOL completed, NSError *error))completionHandler;

@end
