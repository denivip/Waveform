//
//  DVGNoiseFilter_protected.h
//  Waveform
//
//  Created by developer on 25/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

#ifndef DVGNoiseFilter_protected_h
#define DVGNoiseFilter_protected_h

#import "DVGNoiseFilter.h"

@interface DVGNoiseFilter ()

@property (nonatomic, strong) AVAsset *asset;

/**
 *  Audio samples provider
 */
@property (nonatomic) DVGAudioSource* audioSource;

/**
 *  Audio samples writer
 */
@property (nonatomic) DVGAudioWriter* audioWriter;

/**
 *  Processed sound track - descendants put audio here. It should be
 *  PCM data (sound) without encoding.
 */
@property (nonatomic, strong) NSMutableData *processedAudioData;//< TODO: avoid in-memory storage
@property (nonatomic) NSUInteger samplesCount;//< Amount of processed audio samples
//! Может использоваться для отображения прогресса обработки
@property (atomic) NSUInteger processedSamples;//< How many samples have been processed
@property (nonatomic) NSUInteger processedAudioLastSample;//< The last processed sample
@property (nonatomic) NSMutableData* aggregatedProcessedAverageWaveform;
@property (nonatomic) NSMutableData* aggregatedProcessedMaxWaveform;

/**
 *  Method to push processed data sequentially (for aggregate waveform calculation)
 */
- (void)addProcessedSamplesDataWithSampleCount:(SInt16*)readySamples bytesLen:(NSInteger)len;
// FFT params
@property (nonatomic) int log2n;//< FFT base
@property (nonatomic) FFTSetup setup;
@property (nonatomic) float** mInWaveBuffer;//< FFT input buffer
@property (nonatomic) COMPLEX_SPLIT complex_output;//< FFT inplace buffer
@property (nonatomic) int windowSize;//< Amount of real elements to process in FFT
@property (nonatomic) int spectrumSize;//< Amount of spectrums after forward FFT
@property (nonatomic) float* hannWindow;//< Hann window (for FFT outputs)
// Lookahead processing windows
@property (nonatomic) int historyLen;
@property (nonatomic) float** mSpectrums;//< array of history spectrums
@property (nonatomic) float** mGains;//< array of history gains
@property (nonatomic) float** mRealFFTs;//< array of real FFT data
@property (nonatomic) float** mImagFFTs;//< array of imaginary FFT data
// Noise processing cycle variables - per channel
@property (nonatomic) int* inputPos;//< input buffer position (overlap-add algorithm)
@property (nonatomic) int* inSampleCount;//< amount of input samples to process
@property (nonatomic) int* dataOffset;//< offset from the beginning of the data
@property (nonatomic) int* cleanBytesOffset;//<
@property (nonatomic) int* outSampleCount;//< amount of samples produced (cleaned)
@property (nonatomic) int* dataLen;//< data length to process
// Frequency processing internals (noise related)
@property (nonatomic) float noiseAttenFactor;
@property (nonatomic) int minSignalBlocks;

// Auxiliary methods
- (void) fillFirstHistoryWindow:(int)channelNum;
- (void) rotateHistoryWindows:(int)channelNum;

@end


#endif /* DVGNoiseFilter_protected_h */
