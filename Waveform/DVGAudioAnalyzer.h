//
//  DVGAudioAnalyzer.h
//  Denoise
//
//  Created by Denis Bulichenko on 18/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

@import Foundation;
@import CoreMedia;
@import AVFoundation;

extern const float kDVGNoiseFloor;
extern NSString* const kDVGTotalSamplesKey;

#import "PCMReaderProtocol.h"
@interface DVGAudioAnalyzer : NSObject <PCMReaderProtocol>

/**
 * Execute block on processing queue
 */
- (void)runSynchronouslyOnProcessingQueue:(dispatch_block_t)block;
- (void)runAsynchronouslyOnProcessingQueue:(dispatch_block_t)block;

/**
 *  Initializes audio processing from AVAsset
 */
- (instancetype)initWithAsset:(AVAsset *)asset;

/**
 *  Reads audio data and initializes internal buffers, fills current audioFormat
 */
- (void)readAudioData:(void (^)(BOOL completed, NSError *error))completionBlock;

/**
 *  Current audio format
 */
@property (nonatomic) AudioStreamBasicDescription audioFormat;

/**
 *  Analyze aggregated waveform of the audio
 */
//- (void)readAggregateWaveformDataWithSampleCount:(NSUInteger)aggregateSampleCount
//                                      outAverage:(NSMutableData *)avgSamplesData
//                                      outMaximum:(NSMutableData *)maxSamplesData
//                                    maxAmplitude:(SInt16*)maxAmplitude
//                                 completionBlock:(void (^)(NSData *, NSData *, SInt16, NSUInteger))completionBlock;

/**
 *  Analyze aggregated waveform of the audio interval
 */
- (void)readAggregateWaveformIntervalDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                             startSample:(NSUInteger)startSample
                                               endSample:(NSInteger)endSample
                                              outAverage:(NSMutableData *)avgSamplesData
                                              outMaximum:(NSMutableData *)maxSamplesData
                                            maxAmplitude:(SInt16*)maxAmplitude
                                         completionBlock:(void (^)(NSData *, NSData *, SInt16, NSUInteger))completionBlock;

/**
 Сокращаем количество сэмплов для более быстрой отрисовки. Берем среднее по
 абсолютному значению амплитуды и максимальное, чтобы показать красивый
 двухцветный график. Данные обрабатываются по мере доступности.
 */
- (void)copyAggregateProcessedSamplesDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                              outAverage:(NSMutableData *)avgSamplesData
                                              outMaximum:(NSMutableData *)maxSamplesData;

/**
 *  Analyzes frequencies spectrum of audio signal available in audioData parameter.
 *  Returns frequency spectrum of analyzed audio samples.
 */
//- (NSProgress*)analyzeSpectrumStart:(int)fromSample
//                                end:(int)toSample
//                  completionHandler:(void (^)(BOOL completed, NSError *error))completionHandler;

/**
 *  Frequency spectrum of sounds in the asset
 */
@property (nonatomic) float* frequencySpectrum;//< The noise profile of current audio
@property (nonatomic, strong) NSMutableData *channelsFrequencySpectrumProfile;
@property (nonatomic, assign) NSInteger samplesCountInChannel;

//! Data processing progress from 0 (just started) to 100
@property (atomic) float processedData;

- (void)cancelPreviousSpectrumAnalyzing;
@end

@class DVGProgress;
@interface DVGAudioAnalyzer (progresses)
- (DVGProgress *)readFullAggregateWaveformDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                                   outAverage:(NSMutableData *)avgSamplesData
                                                   outMaximum:(NSMutableData *)maxSamplesData
                                                 maxAmplitude:(SInt16*)maxAmplitude;

- (DVGProgress *)analyzeSpectrumStart:(int)fromSample
                                  end:(int)toSample;
@end


