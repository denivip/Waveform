//
//  DVGAudioSamples.h
//  Denoise
//
//  Created by Denis Bulichenko on 17/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

@import Foundation;
@import CoreMedia;
@import AVFoundation;

/**
 *  DVGAudioSource provides an interface to audio samples which
 *  are being used by other sound processing algorithms. It is
 *  intended to use this class on background threads
 */
@interface DVGAudioSource : NSObject

/**
 *  Initialize audio source from AVAsset
 */
- (instancetype)initWithAsset:(AVAsset *)asset;

/**
 *  Get audio samples format
 */
@property (readonly, nonatomic) AudioStreamBasicDescription audioFormat;

/**
 *  Reads audio data and initializes internal buffers
 */
- (void)readAudioFormat:(void (^)(BOOL, NSError *))completionBlock;

/**
 *  Reads all audio samples from the asset and returns samples sequentially via sample block
 */
- (BOOL)readAudioSamplesData:(void (^)(NSData *sampleData, BOOL *stop))sampleBlock
                       error:(NSError * __autoreleasing *)errorOut;

/**
 *  Reads audio samples from a particular time interval in the asset and returns samples
 *  sequentially via sample block
 */
- (BOOL)readAudioSamplesIntervalData:(void (^)(NSData *sampleData, BOOL *stop))sampleBlock
                           timerange:(CMTimeRange)timerange
                               error:(NSError * __autoreleasing *)errorOut;

@end
