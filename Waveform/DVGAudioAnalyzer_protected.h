//
//  DVGAudioAnalyzer_protected.h
//  Denoise
//
//  Created by Denis Bulichenko on 18/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

//#ifndef DVGAudioAnalyzer_protected_h
//#define DVGAudioAnalyzer_protected_h

@import Accelerate;

#import "DVGAudioAnalyzer.h"
#import "DVGAudioSource.h"
#import "DVGAudioWriter.h"
#import "DVGAudioToolboxUtilities.h"



@interface DVGAudioAnalyzer ()

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

//#endif /* DVGAudioAnalyzer_protected_h */
