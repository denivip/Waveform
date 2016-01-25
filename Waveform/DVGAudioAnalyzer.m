//
//  DVGAudioAnalyzer.m
//  Denoise
//
//  Created by Denis Bulichenko on 18/11/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

#import "DVGAudioAnalyzer_protected.h"
#import "DVGProgress.h"
#import "EXTScope.h"

const float kDVGNoiseFloor = -40.0f;
NSString* const kDVGTotalSamplesKey = @"kDVGTotalSamplesKey";

@interface DVGAudioAnalyzer()
@property (atomic, assign) int aggregationTokenSeq;
@property (atomic, assign) int specanalyzeTokenSeq;
@property (nonatomic, strong) dispatch_queue_t processingQueue;
@end

@implementation DVGAudioAnalyzer

/**
 * Initialize AudioProcessor with an asset
 */
- (instancetype)initWithAsset:(AVAsset *)asset
{
    if (self = [super init]) {
        self.asset = asset;
        self.audioSource = [[DVGAudioSource alloc] initWithAsset:asset];
    }
    
    return self;
}

/**
 *  Reads audio data and initializes internal buffers
 */
- (void)readAudioData:(void (^)(BOOL, NSError *))completionBlock
{
    @weakify(self);
    [self runAsynchronouslyOnProcessingQueue:^{
        @strongify(self);
        
        [self.audioSource readAudioFormat:^(BOOL ok, NSError* error){
            if (!ok) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionBlock) completionBlock(NO, error);
                });
                return;
            }
            
            [self prepareForAudioFormat:self.audioSource.audioFormat];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) completionBlock(ok, error);
            });
            
        }];
    }];
}

/**
 *  Sets current audio format and initializes corresponding FFT structures
 */
- (void)prepareForAudioFormat:(AudioStreamBasicDescription)audioFormat
{
    self.audioFormat = audioFormat;
    return;
    [self runSynchronouslyOnProcessingQueue:^{
         NSLog(@"DVGNoiseFilter::prepareForAudioFormat => init FFT environment");
         // FFT init
         self.log2n = 11;//< FFT base
         self.windowSize = 1 << self.log2n;//< Amount of real elements to process in FFT
         self.spectrumSize = 1 + self.windowSize / 2;
         // Initialize the FFT
         FFTSetup fs = self.setup = vDSP_create_fftsetup( self.log2n, 0 );
         if (!fs) {
             // TODO: handle the situation
             NSLog(@"ERROR Failed to vDSP_create_fftsetup");
         }
         // Init frequency analyzer data
         self.frequencySpectrum = calloc(self.spectrumSize, sizeof(float));
         self.channelsFrequencySpectrumProfile = [[NSMutableData alloc] initWithLength:sizeof(float) * self.audioFormat.mChannelsPerFrame * self.spectrumSize];
         
         self.historyLen = 1;
         
         // Initialize internal FFT results buffers - for every channel (stereo)
         self.mSpectrums = malloc(MEMSAFEWARPER*self.audioFormat.mChannelsPerFrame*self.historyLen*sizeof(float*));
         self.mGains = malloc(MEMSAFEWARPER*self.audioFormat.mChannelsPerFrame*self.historyLen*sizeof(float*));
         self.mRealFFTs = malloc(MEMSAFEWARPER*self.audioFormat.mChannelsPerFrame*self.historyLen*sizeof(float*));
         self.mImagFFTs = malloc(MEMSAFEWARPER*self.audioFormat.mChannelsPerFrame*self.historyLen*sizeof(float*));
         for(int i = 0; i < self.audioFormat.mChannelsPerFrame * self.historyLen; i++) {
             self.mSpectrums[i] = calloc(MEMSAFEWARPER*self.spectrumSize, sizeof(float));
             self.mGains[i] = calloc(MEMSAFEWARPER*self.spectrumSize, sizeof(float));
             self.mRealFFTs[i] = calloc(MEMSAFEWARPER*self.spectrumSize, sizeof(float));
             self.mImagFFTs[i] = calloc(MEMSAFEWARPER*self.spectrumSize, sizeof(float));
             for(int j = 0; j < self.spectrumSize; j++) {
                 self.mSpectrums[i][j] = 0;
                 self.mGains[i][j] = self.noiseAttenFactor;
                 self.mRealFFTs[i][j] = 0.0;
                 self.mImagFFTs[i][j] = 0.0;
             }
         }
         
         // Create a Hann window function
         //vDSP_hann_window( mWindow, windowSize, 0);
         self.hannWindow = calloc(self.windowSize , sizeof(float));
        
         for (int i = 0; i < self.windowSize; i++) {
             self.hannWindow[i] = 0.5 - 0.5 * cos((2.0*M_PI*i) / self.windowSize);
         }
         
         // Internal FFT data processing buffers
         self.mInWaveBuffer = calloc(self.audioFormat.mChannelsPerFrame, sizeof(float*));
        
         for (int i = 0; i < self.audioFormat.mChannelsPerFrame; ++i) {
             self.mInWaveBuffer[i] = calloc(self.windowSize, sizeof(float));//< FFT input buffer
         }
         
         COMPLEX_SPLIT csStruct = self.complex_output;
         csStruct.realp = (float *)calloc( self.windowSize, sizeof(float));
         csStruct.imagp = (float *)calloc( self.windowSize, sizeof(float));
         self.complex_output = csStruct;
         
         // Cycled processing variables
         self.inputPos       = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< input buffer position (overlap-add algorithm)
         self.inSampleCount  = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< amount of input samples to process
         self.dataOffset     = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< offset from the beginning of the data
         self.outSampleCount = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< amount of samples produced (cleaned)
         self.dataLen        = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< data length to process
         
         // Aggregated waveforms storage - mac screen length on iOS
         NSInteger kWaveformNumberOfSamples = 2208;
         self.aggregatedProcessedAverageWaveform = [[NSMutableData alloc] initWithLength:kWaveformNumberOfSamples*sizeof(SInt16)];
         self.aggregatedProcessedMaxWaveform     = [[NSMutableData alloc] initWithLength:kWaveformNumberOfSamples*sizeof(SInt16)];
     }];
}

# pragma mark - Frequency analyzer

/**
 *  Analyzes audio spectrum of current asset for the audio samples interval
 *
 *  @return NSProgress of the process
 */

- (void)getFrequencySpectrumOfChannel:(const SInt16 *)samples channel:(int)channelNum {
    // Process audio samples until there are some
    
    SInt16* readPos = (SInt16*)samples;
    while(_dataLen[channelNum] && _outSampleCount[channelNum] < _inSampleCount[channelNum]) {
        int avail = MIN(_dataLen[channelNum], _windowSize - _inputPos[channelNum]);
        
        // Put next samples in the second part of the FFT input buffer (the whole buffer first time)
        vDSP_vflt16(readPos, 2, _mInWaveBuffer[channelNum] + _inputPos[channelNum], 1, avail);
        
        readPos += _audioFormat.mChannelsPerFrame * avail;
        _dataOffset[channelNum] += _audioFormat.mChannelsPerFrame * avail;//< Process one channel at time
        _dataLen[channelNum] -= avail;
        _inputPos[channelNum] += avail;
        
        if (_inputPos[channelNum] == _windowSize) {
            // FillFirstHistoryWindow();
            [self fillFirstHistoryWindow:channelNum];
            
            // Calculate current window noise profile
            [self calculateFrequencySpectrumProfile:channelNum];
            self.outSampleCount[channelNum] += _windowSize / 2;
            
            // RotateHistoryWindows
            [self rotateHistoryWindows:channelNum];
            
            // Rotate halfway for overlap-add
            for(int i = 0; i < _windowSize / 2; i++) {
                _mInWaveBuffer[channelNum][i] = _mInWaveBuffer[channelNum][i + _windowSize / 2];
            }
            _inputPos[channelNum] = _windowSize / 2;
        }
    }
}

/**
 *  Process first window of data
 */
- (void) fillFirstHistoryWindow:(int)channelNum {
     [self runSynchronouslyOnProcessingQueue:^{
         // Prepare data for vDSP
         vDSP_ctoz((COMPLEX *)self.mInWaveBuffer[channelNum], 2, &self->_complex_output, 1, self.windowSize/2);
         // Forward FFT transform
         vDSP_fft_zrip(self.setup, &self->_complex_output, 1, 11, kFFTDirection_Forward);
         
         for(int i = 1; i < self.spectrumSize-1; ++i) {
             self.mRealFFTs[channelNum*self.historyLen][i] = self.complex_output.realp[i];
             self.mImagFFTs[channelNum*self.historyLen][i] = self.complex_output.imagp[i];
             self.mSpectrums[channelNum*self.historyLen][i] = self.mRealFFTs[channelNum*self.historyLen][i]*self.mRealFFTs[channelNum*self.historyLen][i]
             + self.mImagFFTs[channelNum*self.historyLen][i]*self.mImagFFTs[channelNum*self.historyLen][i];
             self.mGains[channelNum*self.historyLen][i] = self.noiseAttenFactor;
         }
         // DC and Fs/2 bins need to be handled specially
         self.mSpectrums[channelNum*self.historyLen][0] = self.complex_output.realp[0]*self.complex_output.realp[0];
         self.mSpectrums[channelNum*self.historyLen][self.spectrumSize-1] =
         self.complex_output.imagp[0]*self.complex_output.imagp[0];
         self.mGains[channelNum*self.historyLen][0] = self.noiseAttenFactor;
         self.mGains[channelNum*self.historyLen][self.spectrumSize-1] = self.noiseAttenFactor;
     }];
}


- (void) calculateFrequencySpectrumProfile:(int)channelNum {
    [self runSynchronouslyOnProcessingQueue:^{
        // The noise threshold for each frequency is the maximum
        // level achieved at that frequency for a minimum of
        // mMinSignalBlocks blocks in a row - the max of a min.
        int start = self.historyLen - self.minSignalBlocks + channelNum*self.historyLen;
        int finish = self.historyLen + channelNum*self.historyLen;
        float *channelsFrequencySpectrumProfile = self.channelsFrequencySpectrumProfile.mutableBytes;
        for (int j = 0; j < self.spectrumSize; ++j) {
            float min = self.mSpectrums[start][j];
            for (int i = start+1; i < finish; ++i) {
                if (self.mSpectrums[i][j] < min) {
                    min = self.mSpectrums[i][j];
                }
            }
            if (sqrtf(min) > channelsFrequencySpectrumProfile[channelNum * self.spectrumSize + j]) {
                self.frequencySpectrum[j] = min;
                channelsFrequencySpectrumProfile[channelNum * self.spectrumSize + j] = sqrtf(min);
            }
        }
    }];
}

/**
 *  Rotate history windows
 */
- (void) rotateHistoryWindows:(int)channelNum {
    int last = _historyLen - 1 + channelNum*_historyLen;
    // Remember the last window so we can reuse it
    float *lastSpectrum = _mSpectrums[last];
    float *lastGain = _mGains[last];
    float *lastRealFFT = _mRealFFTs[last];
    float *lastImagFFT = _mImagFFTs[last];
    
    // Rotate each history window forward
    for(int i = last; i >= 1+channelNum*_historyLen; i--) {
        _mSpectrums[i] = _mSpectrums[i-1];
        _mGains[i] = _mGains[i-1];
        _mRealFFTs[i] = _mRealFFTs[i-1];
        _mImagFFTs[i] = _mImagFFTs[i-1];
    }
    
    // Reuse the last buffers as the new first window
    _mSpectrums[channelNum*_historyLen] = lastSpectrum;
    _mGains[channelNum*_historyLen] = lastGain;
    _mRealFFTs[channelNum*_historyLen] = lastRealFFT;
    _mImagFFTs[channelNum*_historyLen] = lastImagFFT;
}

#pragma mark - Waveform analyzer

/**
 *  Calculates aggregated waveform of original audio with requested precision (samples count)
 */
//- (void)readAggregateWaveformDataWithSampleCount:(NSUInteger)aggregateSampleCount
//                                      outAverage:(NSMutableData *)avgSamplesData
//                                      outMaximum:(NSMutableData *)maxSamplesData
//                                    maxAmplitude:(SInt16*)maxAmplitude
//                                 completionBlock:(void (^)(NSData *, NSData *, SInt16, NSUInteger))completionBlock
//{
//    [self readAggregateWaveformIntervalDataWithSampleCount:aggregateSampleCount
//                                               startSample:0
//                                                 endSample:0
//                                                outAverage:avgSamplesData
//                                                outMaximum:maxSamplesData
//                                              maxAmplitude:maxAmplitude
//                                           completionBlock:completionBlock];
//}

- (void)cancelAggreagations {
    self.aggregationTokenSeq++;
}

/**
 *  Calculates aggregated waveform of original audio samples interval with requested precision (samples count)
 */
- (void)readAggregateWaveformIntervalDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                             startSample:(NSUInteger)startSample
                                               endSample:(NSInteger)endSample
                                              outAverage:(NSMutableData *)avgSamplesData
                                              outMaximum:(NSMutableData *)maxSamplesData
                                            maxAmplitude:(SInt16*)maxAmplitude
                                         completionBlock:(void (^)(NSData *, NSData *, SInt16, NSUInteger))completionBlock
{
    NSLog(@"readAggregateWaveformIntervalDataWithSampleCount: %lu-%lu", startSample, endSample);
    [self cancelAggreagations];
    int thisAttemptAggregationToken = self.aggregationTokenSeq;
    @weakify(self);
    [self runAsynchronouslyOnProcessingQueue:^{
        @strongify(self);
        
        NSUInteger samplesCount;
        [self _readAggregateWaveformWithSampleCount:aggregateSampleCount
                                        startSample:startSample
                                          endSample:endSample
                                        avegareData:avgSamplesData
                                        maximumData:maxSamplesData
                                   maximumAmplitude:maxAmplitude
                                       samplesCount:&samplesCount
                            attemptAggregationToken:thisAttemptAggregationToken];
        if(thisAttemptAggregationToken == self.aggregationTokenSeq){
            self.samplesCount = samplesCount * self.audioFormat.mChannelsPerFrame;
            dispatch_async(dispatch_get_main_queue(), ^{
                if(thisAttemptAggregationToken == self.aggregationTokenSeq){
                    if (completionBlock) completionBlock(avgSamplesData,
                                                         maxSamplesData,
                                                         maxAmplitude,
                                                         samplesCount);
                }
            });
        }else{
            NSLog(@"readAggregateWaveformIntervalDataWithSampleCount: %lu-%lu result skipped (another one in progress)", startSample, endSample);
            dispatch_async(dispatch_get_main_queue(), ^{
                    if (completionBlock) completionBlock(nil,
                                                         nil,
                                                         0,
                                                         0);
            });
        }
    }];
}

- (void)_readAggregateWaveformWithSampleCount:(NSUInteger)aggregateSampleCount
                                  startSample:(NSUInteger)startSample
                                    endSample:(NSUInteger)endSample
                                  avegareData:(NSMutableData *)avgSamplesDataOut
                                  maximumData:(NSMutableData *)maxSamplesDataOut
                             maximumAmplitude:(SInt16 *)maxAmplitudeOut
                                 samplesCount:(NSUInteger *)samplesCountOut
                      attemptAggregationToken:(int)thisAttemptAggregationToken
{
    CMTime startTime=startSample?CMTimeMake(startSample,_audioFormat.mSampleRate):(kCMTimeZero);
    CMTime endTime  =  endSample?CMTimeMake(  endSample,_audioFormat.mSampleRate):([self asset].duration);
    CMTimeRange audioTimeRange = CMTimeRangeMake(startTime, CMTimeSubtract(endTime, startTime));
    NSLog(@"startTime=%.1f <=> endTime=%.1f", (float)startTime.value/startTime.timescale, (float)endTime.value/endTime.timescale);
    
    // Samples in one channel
    NSUInteger estimatedSampleCount = (NSTimeInterval)CMTimeGetSeconds(audioTimeRange.duration) * _audioFormat.mSampleRate;
    
    // How many original samples per one aggregated
    NSUInteger sampleBlockLength = estimatedSampleCount / aggregateSampleCount;
    NSLog(@"sampleBlockLength=%lu, estimatedSampleCount=%lu, aggregateSampleCount=%lu", sampleBlockLength, estimatedSampleCount, aggregateSampleCount);
    
    // Initialize average samples data
    NSMutableData *avgSamplesDataDouble = [[NSMutableData alloc] initWithLength:aggregateSampleCount * sizeof(double)];
    double *avgSamplesDouble = avgSamplesDataDouble.mutableBytes;
    // Initialize maximum samples data
    NSMutableData *maxSamplesData = [[NSMutableData alloc] initWithLength:aggregateSampleCount * sizeof(SInt16)];
    SInt16 *maxSamples = maxSamplesData.mutableBytes;
    for (NSUInteger i = 0; i < aggregateSampleCount; i++) {
        avgSamplesDouble[i] = kDVGNoiseFloor;
        maxSamples[i] = (SInt16)kDVGNoiseFloor;
    }
    
    __block NSUInteger idx = 0;
    __block SInt16 maxAmplitude = kDVGNoiseFloor;
    __block NSUInteger samplesCount = 0;
    //__block NSInteger prevBlock = -1;
    NSUInteger channelsCount = _audioFormat.mChannelsPerFrame;
    [self.audioSource readAudioSamplesIntervalData:^(NSData *data, BOOL *stop) {
        NSUInteger dataSamplesCount = data.length / sizeof(SInt16) / channelsCount;
        const SInt16 *dataSamples = data.bytes;
        for (NSUInteger jdx = 0; jdx < dataSamplesCount; jdx++) {
            if(thisAttemptAggregationToken != self.aggregationTokenSeq){
                // another attempt started, stopping this one
                *stop = YES;
                break;
            }
            NSUInteger block = idx / sampleBlockLength;
            if (block > aggregateSampleCount) {
                continue;
            }
            SInt16 sample = dataSamples[channelsCount * jdx];
            avgSamplesDouble[block] += fabs((double)sample / (double)sampleBlockLength);
            
            if (maxSamples[block] < sample) {
                maxSamples[block] = sample;
            }
            if (maxAmplitude < sample) {
                *maxAmplitudeOut = maxAmplitude = sample;
            }
            
            //sample = (SInt16)avgSamplesDouble[block];
            SInt16 *asdo = avgSamplesDataOut.mutableBytes;
            asdo[block] = (SInt16)avgSamplesDouble[block];
            SInt16 *msdo = maxSamplesDataOut.mutableBytes;
            msdo[block] = (SInt16)maxSamples[block];
//            if(prevBlock != block){
//                if(prevBlock >= 0){
//                    NSLog(@"Sampled values: %ld. avg=%i max=%i",prevBlock, asdo[prevBlock],msdo[prevBlock]);
//                }
//                prevBlock = block;
//            }
            idx++;
        }
        
        samplesCount += dataSamplesCount;
    } timerange:audioTimeRange error:NULL];
    if(thisAttemptAggregationToken == self.aggregationTokenSeq){
        *maxAmplitudeOut = maxAmplitude;
        *samplesCountOut = samplesCount;
    }
}

/*
 *  Calculates aggregated waveform of cleaned audio with requested precision (samples count)
 */
- (void)copyAggregateProcessedSamplesDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                              outAverage:(NSMutableData *)avgSamplesData
                                              outMaximum:(NSMutableData *)maxSamplesData
{
    // Increase length if needed
    if (self.aggregatedProcessedAverageWaveform.length != aggregateSampleCount*sizeof(SInt16)) {
        self.aggregatedProcessedAverageWaveform.length = aggregateSampleCount*sizeof(SInt16);
        self.aggregatedProcessedMaxWaveform.length = aggregateSampleCount*sizeof(SInt16);
    }
    // Добавим данные в общий массив
    memcpy(avgSamplesData.mutableBytes,
           self.aggregatedProcessedAverageWaveform.bytes,
           self.aggregatedProcessedAverageWaveform.length);
    memcpy(maxSamplesData.mutableBytes,
           self.aggregatedProcessedMaxWaveform.bytes,
           self.aggregatedProcessedMaxWaveform.length);
}

/*
 *  Calculates aggregated waveform of cleaned audio with requested precision (samples count)
 */
- (void)addProcessedSamplesDataWithSampleCount:(SInt16*)readySamples bytesLen:(NSInteger)len
{
    AudioStreamBasicDescription audioFormat = self.audioFormat;
    NSUInteger lastSample = self.processedSamples / audioFormat.mChannelsPerFrame;
    if (self.processedAudioLastSample >= lastSample) {
        return;
    }
    NSRange range = NSMakeRange(self.processedAudioLastSample, lastSample - self.processedAudioLastSample);

    NSUInteger channelsCount = audioFormat.mChannelsPerFrame;
    NSUInteger sampleBlockLength = self.samplesCount / channelsCount / (self.aggregatedProcessedAverageWaveform.length/sizeof(SInt16));
    const SInt16 *samples = readySamples;

    // Process the data range received
    // Для вычисления среднего используем числа с плавающей точкой, чтобы
    // избежать эффектов переполнения и округления до целого, затем
    // переводим в стандартный формат SInt16.

    NSUInteger firstBlock = range.location / sampleBlockLength;
    NSUInteger tillBlock = (range.location + range.length - 1) / sampleBlockLength + 1;
    NSMutableData *blockAvgData = [[NSMutableData alloc] initWithLength:(tillBlock - firstBlock) * sizeof(CGFloat)];
    NSMutableData *blockMaxData = [[NSMutableData alloc] initWithLength:(tillBlock - firstBlock) * sizeof(SInt16)];
    CGFloat *blockAvg = blockAvgData.mutableBytes;
    SInt16 *blockMax = blockMaxData.mutableBytes;

    for (NSUInteger idx = range.location; idx < range.location + range.length; ++idx) {
        NSInteger block = idx / sampleBlockLength - firstBlock;
        NSInteger samplePos = channelsCount * (idx - self.processedAudioLastSample);
        if(samplePos >= len/sizeof(SInt16)){
            NSLog(@"ERROR: read Buffer overflow!!!");
        }
        SInt16 sample = samples[samplePos]; // берем только канал 0
        blockAvg[block] += (CGFloat)ABS(sample) / sampleBlockLength;
        if (sample > blockMax[block]) {
            blockMax[block] = sample;
        }
    }

    SInt16 *avgSamples = self.aggregatedProcessedAverageWaveform.mutableBytes;
    SInt16 *maxSamples = self.aggregatedProcessedMaxWaveform.mutableBytes;
    for (NSUInteger idx = firstBlock; idx < tillBlock; ++idx) {
        avgSamples[idx] += (SInt16)blockAvg[idx - firstBlock];
        if (maxSamples[idx] < blockMax[idx - firstBlock]){
            maxSamples[idx] = blockMax[idx - firstBlock];
        }
    }

    self.processedAudioLastSample = range.location + range.length;
}

#pragma mark - Internals

- (dispatch_queue_t)processingQueue
{
    if (!_processingQueue) {
        _processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL);
    }
    return _processingQueue;
}

- (void)runSynchronouslyOnProcessingQueue:(dispatch_block_t)block
{
    dispatch_queue_t pq = self.processingQueue;
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(pq)){
        @autoreleasepool {
            block();
        }
    }else
    {
        dispatch_sync(pq, block);
    }
}

- (void)runAsynchronouslyOnProcessingQueue:(dispatch_block_t)block
{
    dispatch_queue_t pq = self.processingQueue;
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(pq)){
        @autoreleasepool {
            block();
        }
    }else
    {
        dispatch_async(pq, block);
    }
}


- (void)cancelPreviousSpectrumAnalyzing {
    self.specanalyzeTokenSeq++;
}

- (void)cancelPreviousFiltering {
}

@end


@implementation DVGAudioAnalyzer (progresses)
- (DVGProgress *)readFullAggregateWaveformDataWithSampleCount:(NSUInteger)aggregateSampleCount
                                                   outAverage:(NSMutableData *)avgSamplesDataOut
                                                   outMaximum:(NSMutableData *)maxSamplesDataOut
                                                 maxAmplitude:(SInt16*)maxAmplitudeOut {
    [self cancelAggreagations];
    int thisAttemptAggregationToken = self.aggregationTokenSeq;
    CMTime startTime = kCMTimeZero;
    CMTime endTime   = self.asset.duration;
    CMTimeRange audioTimeRange = CMTimeRangeMake(startTime, CMTimeSubtract(endTime, startTime));
    NSLog(@"startTime=%.1f <=> endTime=%.1f", (float)startTime.value/startTime.timescale, (float)endTime.value/endTime.timescale);
    
    NSUInteger channelsCount = _audioFormat.mChannelsPerFrame;
    // Samples in one channel
    NSUInteger estimatedSampleCount = (NSTimeInterval)CMTimeGetSeconds(audioTimeRange.duration) * _audioFormat.mSampleRate;
    DVGProgress *progress = (DVGProgress *)[DVGProgress progressWithTotalUnitCount:estimatedSampleCount*1.1];// Should not finish before finish
    progress.userDescription = NSLocalizedString(@"Loading sound", nil);
    NSLog(@"estimatedSampleCount=%lu", (unsigned long)estimatedSampleCount);
    
    // How many original samples per one aggregated
    NSUInteger sampleBlockLength = estimatedSampleCount / aggregateSampleCount;
    NSLog(@"sampleBlockLength=%lu, aggregateSampleCount=%lu", (unsigned long)sampleBlockLength, (unsigned long)aggregateSampleCount);

    [self runAsynchronouslyOnProcessingQueue:^{
        if(thisAttemptAggregationToken != self.aggregationTokenSeq){
            // another attempt started, stopping this one
            return;
        }
        // Initialize average samples data
        NSMutableData *avgSamplesDataDouble = [[NSMutableData alloc] initWithLength:aggregateSampleCount * sizeof(double)];
        double *avgSamplesDouble = avgSamplesDataDouble.mutableBytes;
        // Initialize maximum samples data
        NSMutableData *maxSamplesData = [[NSMutableData alloc] initWithLength:aggregateSampleCount * sizeof(SInt16)];
        SInt16 *maxSamples = maxSamplesData.mutableBytes;
        for (NSUInteger i = 0; i < aggregateSampleCount; i++) {
            avgSamplesDouble[i] = kDVGNoiseFloor;
            maxSamples[i] = (SInt16)kDVGNoiseFloor;
        }
    
        __block NSUInteger idx = 0;
        __block SInt16 maxAmplitude = kDVGNoiseFloor;
        __block NSUInteger samplesCount = 0;
        
        void(^sampleBlock)(NSData *sampleData, BOOL *stop) = ^(NSData *data, BOOL *stop) {
            NSUInteger dataSamplesCount = data.length / sizeof(SInt16) / channelsCount;
            const SInt16 *dataSamples = data.bytes;
            
            for (NSUInteger jdx = 0; jdx < dataSamplesCount; jdx++) {
                NSUInteger block = idx / sampleBlockLength;
                
                if (block > aggregateSampleCount){
                    continue;
                }
                SInt16 sample = dataSamples[channelsCount * jdx];
                avgSamplesDouble[block] += fabs((double)sample / sampleBlockLength);
                
                if (maxSamples[block] < sample)
                    maxSamples[block] = sample;
                
                if (maxAmplitude < sample) {
                    *maxAmplitudeOut = maxAmplitude = sample;
                }
                if (block >= 10) {
                    abort();
                }
                SInt16 *asdo = avgSamplesDataOut.mutableBytes;
                asdo[block] = (SInt16)avgSamplesDouble[block];
                SInt16 *msdo = maxSamplesDataOut.mutableBytes;
                msdo[block] = maxSamples[block];
                printf("%hd, %.4f, %.4f\n", sample, fabs((double)sample / sampleBlockLength), avgSamplesDouble[block]);
                idx++;
            }
            
            samplesCount += dataSamplesCount;
            progress.completedUnitCount = (int64_t)samplesCount;
            if(thisAttemptAggregationToken != self.aggregationTokenSeq){
                // another attempt started, stopping this one
                *stop = YES;
            }
            if (progress.cancelled){
                *stop = YES;
            }
        };
        
        if(![self.audioSource readAudioSamplesIntervalData:sampleBlock
                                             timerange:audioTimeRange
                                                      error:NULL]){
            samplesCount = 0;
        }
        if(maxAmplitude == 0){
            samplesCount = 0;
        }
        progress.liveContext[kDVGTotalSamplesKey] = @(samplesCount);
        if(thisAttemptAggregationToken != self.aggregationTokenSeq){
            [progress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
            return;
        }
        if (samplesCount == 0) {
            NSError *error = [NSError errorWithDomain:@"ErrorDomain"
                                                 code:0
                                             userInfo:@{ NSLocalizedDescriptionKey : NSLocalizedString(@"Error reading audio data", nil) }];
            [progress completeWithError:error];
            return;
        }

        self.samplesCount = samplesCount * self.audioFormat.mChannelsPerFrame;
        [progress completeWithError:nil];
    }];

    return progress;
}

- (DVGProgress *)analyzeSpectrumStart:(int)fromSample
                                  end:(int)toSample {
    
    NSLog(@"Analyzing a frequency spectrum for samples [%d-%d]",fromSample, toSample);
    [self cancelPreviousSpectrumAnalyzing];
    int thisAttemptspecanalyzeToken = self.specanalyzeTokenSeq;
    DVGProgress* analyzeProgress = (DVGProgress *)[DVGProgress progressWithTotalUnitCount:CMTimeGetSeconds(self.asset.duration) * self.audioFormat.mSampleRate];
    analyzeProgress.userDescription = NSLocalizedString(@"Analyzing sound", nil);
    analyzeProgress.cancellable = YES;
    analyzeProgress.pausable = NO;
    
    @weakify(self);
    [self runAsynchronouslyOnProcessingQueue:^{
        @strongify(self);
        if(thisAttemptspecanalyzeToken != self.specanalyzeTokenSeq){
            [analyzeProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
            return;
        }
        unsigned int channelsCount = self.audioFormat.mChannelsPerFrame;
        self.channelsFrequencySpectrumProfile = [[NSMutableData alloc] initWithLength:sizeof(float) * self.audioFormat.mChannelsPerFrame * self.spectrumSize];
        float *channelsFrequencySpectrumProfile = self.channelsFrequencySpectrumProfile.mutableBytes;
        
        // Setup frequency analyzer position and duration
        for (int i = 0; i < self.audioFormat.mChannelsPerFrame; ++i) {
            self.inputPos[i] = 0;
            self.outSampleCount[i] = -(self.windowSize / 2) * (self.historyLen - 1);
            // Whole audio buffer is processed by default
            if (fromSample==toSample && fromSample==0) {
                self.inSampleCount[i] = (int)self.samplesCount / self.audioFormat.mChannelsPerFrame;
                self.dataOffset[i] = 0;
            } else {
                self.inSampleCount[i] = toSample-fromSample;
                self.dataOffset[i] = self.audioFormat.mChannelsPerFrame*fromSample;
            }
            self.dataLen[i] = self.inSampleCount[i];
        }
        // Initialize noise thresholds (remove previous calculations if any)
        for (int i = 0; i < self.spectrumSize; ++i) {
            self.frequencySpectrum[i] = 0.0f;
            for (int j = 0; j < self.audioFormat.mChannelsPerFrame ; ++j) {
                channelsFrequencySpectrumProfile[j * self.spectrumSize + i] = 0;
            }
        }
        
        // Read audio samples in chunks
        NSLog(@"Getting a noise profile for %u channels", channelsCount);
        
        int __block readCount = 0;
        int __block cycle = 0;
        
        void(^samplesDataBlock)(NSData *data, BOOL *stop) = ^(NSData *data, BOOL *stop) {
           
            ++cycle;
            NSUInteger dataSamplesCount = data.length / sizeof(SInt16) / channelsCount;
            readCount += dataSamplesCount;
            
            if (fromSample<readCount) {
                const SInt16 *dataSamples = data.bytes;
            
                for (int i = 0; i < channelsCount; ++i) {
                    if (fromSample == toSample && fromSample == 0) {
                        self.inSampleCount[i] += dataSamplesCount;
                    }
                    self.dataLen[i] = dataSamplesCount;
                    self.dataOffset[i] = 0;
                    [self getFrequencySpectrumOfChannel:(dataSamples+i) channel:i];
                }
            }
            // Update progress every 50th iteration
            if (cycle%50 == 0) {
                analyzeProgress.completedUnitCount = readCount;
            }
            
            if(thisAttemptspecanalyzeToken != self.specanalyzeTokenSeq){
                *stop = YES;
            }
            if (analyzeProgress.cancelled){
                *stop = YES;
            }
        };
        
        [self.audioSource readAudioSamplesData:samplesDataBlock
                                         error:NULL];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(thisAttemptspecanalyzeToken != self.specanalyzeTokenSeq){
                [analyzeProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
            }else{
                [analyzeProgress completeWithError:nil];
            }
        });
    }];
    
    return analyzeProgress;
}

@end
