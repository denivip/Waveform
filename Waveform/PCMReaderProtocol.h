//
//  PCMReaderProtocol.h
//  Denoise
//
//  Created by developer on 15/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

#ifndef PCMReaderProtocol_h
#define PCMReaderProtocol_h
@import Foundation;
@protocol PCMReaderProtocol <NSObject>

- (void)readAudioData:(void (^)(BOOL completed, NSError *error))completionBlock;
- (void)runAsynchronouslyOnProcessingQueue:(dispatch_block_t)block;
- (NSProgress *)readFullAggregateWaveformDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                                   outAverage:(NSMutableData *)avgSamplesDataOut
                                                   outMaximum:(NSMutableData *)maxSamplesDataOut
                                                 maxAmplitude:(SInt16*)maxAmplitudeOut;
//Noize Filter

@optional
@property (nonatomic) float* frequencySpectrum;//< The noise profile of current audio
@property (nonatomic, assign) NSInteger samplesCountInChannel;
@property (nonatomic, readonly, copy) NSArray *oneChannelNoiseProfile;
- (void)cancelPreviousSpectrumAnalyzing;
- (void)cancelPreviousFiltering;

@end

#endif /* PCMReaderProtocol_h */
