//
//  DVGAudioProcessor.m
//  Denoise
//
//  Created by Denis Bulichenko on 27/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

@import Accelerate;
@import Darwin.AssertMacros;

#import "DVGNoiseFilter.h"
#import "DVGAudioSource.h"
#import "DVGAudioWriter.h"
#import "DVGAudioToolboxUtilities.h"
#import "DVGProgress.h"
#import "DVGNoiseFilter_protected.h"

@interface DVGNoiseFilter ()

// Noise filtering params by default
@property (nonatomic) float noiseSensitivity;
@property (nonatomic) float noiseGain;
@property (nonatomic) float freqSmoothingHz;
@property (nonatomic) float attackDecayTime;
@property (nonatomic) float minSignalTime;

// Noise reduction variables
@property (nonatomic) int freqSmoothingBins;
@property (nonatomic) int attackDecayBlocks;
@property (nonatomic) float oneBlockAttackDecay;
@property (nonatomic) float sensitivityFactor;
// Noise reduction cycle variables - per channel buffers
@property (nonatomic) float** obtainedReal;
@property (nonatomic) float** outOverlapBuffer;
@property (atomic, assign) int filteringTokenSeq;
@property (nonatomic, strong) dispatch_queue_t processingQueue;

@end


@implementation DVGNoiseFilter
@synthesize channelsCount = _channelsCount, identifier = _identifier;
- (instancetype)initWithAsset:(AVAsset *)asset
{
    if (self = [super init]) {
        self.asset = asset;
        self.audioSource = [[DVGAudioSource alloc] initWithAsset:asset];
    }
    
    return self;
}

/**
 *  Sets current audio format and initializes corresponding FFT structures
 */
- (void)prepareForAudioFormat:(AudioStreamBasicDescription)audioFormat
{
     [self runSynchronouslyOnProcessingQueue:^{
         self.audioFormat = audioFormat;
         
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
         
         // Noise removal default settings
         self.noiseSensitivity = 0.0;
         self.noiseGain = -32.0;
         self.freqSmoothingHz = 150.0;
         self.attackDecayTime = 0.15f;
         self.minSignalTime = 0.05f;
         
         // Noise removal params
         self.noiseAttenFactor = pow(10.0, self.noiseGain/20.0);
         self.minSignalBlocks = (int)(self.minSignalTime * self.audioFormat.mSampleRate / (self.windowSize / 2));
         if( self.minSignalBlocks < 1 ) {
             self.minSignalBlocks = 1;
         }
         self.historyLen = (2 * self.attackDecayBlocks) - 1;
         if (self.historyLen < self.minSignalBlocks) {
             self.historyLen = self.minSignalBlocks;
         }
         
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
         self.hannWindow = calloc(self.windowSize, sizeof(float));
         for(int i=0; i<self.windowSize; i++) {
             self.hannWindow[i] = 0.5 - 0.5 * cos((2.0*M_PI*i) / self.windowSize);
         }
         
         // Internal FFT data processing buffers
         self.mInWaveBuffer = calloc(self.audioFormat.mChannelsPerFrame, sizeof(float*));
         self.obtainedReal = calloc(self.audioFormat.mChannelsPerFrame, sizeof(float*));
         self.outOverlapBuffer = calloc(self.audioFormat.mChannelsPerFrame, sizeof(float*));
         for (int i=0; i<self.audioFormat.mChannelsPerFrame; ++i) {
             self.mInWaveBuffer[i] = calloc(self.windowSize, sizeof(float));//< FFT input buffer
             self.obtainedReal[i] = (float *) malloc(self.windowSize * sizeof(float));//< Denoised audio samples will be stored here
             self.outOverlapBuffer[i] = calloc(self.windowSize, sizeof(float));//< Overlap-add algorithm
         }
         
         COMPLEX_SPLIT csStruct = self.complex_output;
         csStruct.realp = (float *)calloc( self.windowSize, sizeof(float));
         csStruct.imagp = (float *)calloc( self.windowSize, sizeof(float));
         self.complex_output = csStruct;
         
         // Cycled processing variables
         self.inputPos = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< input buffer position (overlap-add algorithm)
         self.inSampleCount = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< amount of input samples to process
         self.dataOffset = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< offset from the beginning of the data
         self.cleanBytesOffset = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< offset from the beginning of the data
         self.outSampleCount = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< amount of samples produced (cleaned)
         self.dataLen = calloc(self.audioFormat.mChannelsPerFrame, sizeof(int));//< data length to process
         
         // Initialize noise reduction configuration
         self.freqSmoothingBins = (int)(self.freqSmoothingHz * self.windowSize / self.audioFormat.mSampleRate);
         self.attackDecayBlocks = 1 + (int)(self.attackDecayTime * self.audioFormat.mSampleRate / (self.windowSize / 2));
         self.oneBlockAttackDecay = pow(10.0, (self.noiseGain / (20.0 * self.attackDecayBlocks)));
         self.sensitivityFactor = pow(10.0, self.noiseSensitivity/10.0);
         
         // Aggregated waveforms storage - mac screen length on iOS
         NSInteger kWaveformNumberOfSamples = 2208;
         self.aggregatedProcessedAverageWaveform = [[NSMutableData alloc] initWithLength:kWaveformNumberOfSamples*sizeof(SInt16)];
         self.aggregatedProcessedMaxWaveform = [[NSMutableData alloc] initWithLength:kWaveformNumberOfSamples*sizeof(SInt16)];
     }];
}

- (NSArray *)oneChannelNoiseProfile
{
    float *channelsNoiseProfile = self.channelsFrequencySpectrumProfile.mutableBytes;
    NSMutableArray *profileArray = [NSMutableArray arrayWithCapacity:self.spectrumSize];
    for (int i = 0; i < self.spectrumSize; i++) {
        [profileArray addObject:@(channelsNoiseProfile[i])];
    }

    // Only the first channel's frequency spectrum is returned
    // We might wanna fix it later
    return profileArray;
}

- (void)cancelPreviousFiltering {
    self.filteringTokenSeq++;
    if([self.audioWriter isWritingAnything]){
        [self runSynchronouslyOnProcessingQueue:^{
            [self.audioWriter closeAudioFile];
        }];
    }
}

/**
 *  Filters PCM audio
 */
- (DVGProgress *) filterAnalyzedAudio {
    [self cancelPreviousFiltering];
    NSLog(@"filterAnalyzedAudio: samples=%ld", (long)self.samplesCountInChannel);
    DVGProgress* filterProgress = (DVGProgress *)[DVGProgress progressWithTotalUnitCount:self.samplesCountInChannel+1];
    filterProgress.userDescription = NSLocalizedString(@"Filtering sound", nil);
    filterProgress.cancellable = YES;
    filterProgress.pausable = NO;
    __block NSInteger cycle = 0;
    int activeFilteringTokenSeq = self.filteringTokenSeq;
    
    [self runAsynchronouslyOnProcessingQueue:^{
        // Clear audio buffers and reset positions
        for(int i = 0; i < self.audioFormat.mChannelsPerFrame * self.historyLen; ++i) {
            for(int j = 0; j < self.spectrumSize; ++j) {
                self.mSpectrums[i][j] = 0.0;
                self.mGains[i][j] = self.noiseAttenFactor;
                self.mRealFFTs[i][j] = 0.0;
                self.mImagFFTs[i][j] = 0.0;
            }
        }
        memset(self.complex_output.realp, 0, self.windowSize * sizeof(float) / 2);
        memset(self.complex_output.imagp, 0, self.windowSize * sizeof(float) / 2);
        for (int i=0; i<self.audioFormat.mChannelsPerFrame; ++i) {
            memset(self.mInWaveBuffer[i], 0, self.windowSize * sizeof(float));
            self.inSampleCount[i] = 0;
            self.outSampleCount[i] = -(self.windowSize / 2) * (self.historyLen - 1);
            self.dataLen[i] = self.inSampleCount[i]-self.outSampleCount[i];
            self.inputPos[i] = 0;
            self.dataOffset[i] = 0;
        }
        
        self.processedAudioLastSample = 0;
        self.processedSamples = 0;
        self.processedAudioData = [[NSMutableData alloc] initWithLength:self.samplesCount * sizeof(SInt16)];

        // Create a new temporary audio file
        self.audioWriter = [[DVGAudioWriter alloc] initWithAudioSamples:self.processedAudioData ofFormat:self.audioFormat];
        [self.audioWriter createAudioFile];
    
        // Read source audio file and filter samples on the fly
        UInt32 channelsCount = self.audioFormat.mChannelsPerFrame;
        [self.audioSource readAudioSamplesData:^(NSData *adata, BOOL *stop) {
            //[self runSynchronouslyOnProcessingQueue:^{
            if(activeFilteringTokenSeq != self.filteringTokenSeq || filterProgress.cancelled){
                *stop = YES;
                if(!filterProgress.isCompleted){
                    [filterProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
                }
                return;
            }
            NSUInteger dataSamplesCount = adata.length / sizeof(SInt16) / channelsCount;
            NSMutableData* cleanOutputBuffer = [[NSMutableData alloc] initWithLength:MAX(adata.length,self.audioFormat.mSampleRate)];
            NSMutableData* data = adata.mutableCopy;
            SInt16 *dataSamples = data.mutableBytes;
            for (int i = 0; i < channelsCount; ++i) {
                self.dataLen[i] = (int)dataSamplesCount;
                self.inSampleCount[i] += dataSamplesCount;
                self.dataOffset[i] = 0;
                self.cleanBytesOffset[i] = 0;
                [self removeNoiseFromChannel:dataSamples+i channel:i withFilteringToken:activeFilteringTokenSeq outputBuffer:cleanOutputBuffer];
            }
            if(activeFilteringTokenSeq != self.filteringTokenSeq || filterProgress.cancelled){
                *stop = YES;
                if(!filterProgress.isCompleted){
                    [filterProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
                }
                return;
            }
            // Write clean audio into temporary audio file
            NSInteger readySamplesCnt = MAX(0, self.outSampleCount[channelsCount-1]);
            NSInteger writtenSamplesCnt = self.processedSamples;
            NSInteger bytesLength = (channelsCount * readySamplesCnt - writtenSamplesCnt) * sizeof(SInt16);
            //cleanOutputBuffer.length = bytesLength;
            if(bytesLength >= cleanOutputBuffer.length){
                NSLog(@"ERROR: Inner Buffer overflow!!!! Fire in the hole!!!");
            }
            [self.audioWriter appendBytesToAudioFile:cleanOutputBuffer.mutableBytes bytesLen:bytesLength];
            
            self.processedSamples = channelsCount * readySamplesCnt;
            self.processedData = (float) self.processedSamples / self.samplesCount;
            [self addProcessedSamplesDataWithSampleCount:cleanOutputBuffer.mutableBytes bytesLen:bytesLength];
            if (cycle%50 == 0) {
                filterProgress.completedUnitCount = readySamplesCnt;
            }
            cycle++;
            //}];
        } error:NULL];
        if(activeFilteringTokenSeq != self.filteringTokenSeq || filterProgress.cancelled){
            if(!filterProgress.isCompleted){
                [filterProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
            }
            return;
        }

        // Push zeros into input buffers when finished reading file
        // in order to push final samples out of FFT processors
        size_t samplesLeft = 0;
        for (int i = 0; i < channelsCount; i++) {
            samplesLeft += (self.inSampleCount[i] - self.outSampleCount[i]);
        }
        
        if (samplesLeft) {
            SInt16* dataSamples = calloc(samplesLeft, sizeof(SInt16));
            NSMutableData* cleanOutputBuffer = [[NSMutableData alloc] initWithLength:MAX(samplesLeft*sizeof(SInt16)*channelsCount,self.audioFormat.mSampleRate)];
            for (int i = 0; i < self.audioFormat.mChannelsPerFrame; ++i) {
                self.dataLen[i] = self.inSampleCount[i] - self.outSampleCount[i];
                self.dataOffset[i] = 0;
                [self removeNoiseFromChannel:dataSamples + i channel:i withFilteringToken:activeFilteringTokenSeq outputBuffer:cleanOutputBuffer];
            }
            free(dataSamples);

            if(activeFilteringTokenSeq != self.filteringTokenSeq || filterProgress.cancelled){
                if(!filterProgress.isCompleted){
                    [filterProgress completeWithError:[NSError errorWithDomain:@"ErrorDomain" code:1 userInfo:nil]];
                }
                return;
            }
            NSUInteger bytesLength = samplesLeft * sizeof(SInt16);
            //cleanOutputBuffer.length = bytesLength;
            [self.audioWriter appendBytesToAudioFile:cleanOutputBuffer.mutableBytes bytesLen:bytesLength];
            self.processedSamples = MAX(0, (int)channelsCount * MAX(0, self.outSampleCount[channelsCount - 1]) - samplesLeft);
            [self addProcessedSamplesDataWithSampleCount:cleanOutputBuffer.mutableBytes bytesLen:bytesLength];
        }
        
        [self.audioWriter closeAudioFile];
        [filterProgress completeWithError:nil];
    }];
    return filterProgress;
}

/**
 *  Performs actual noise removal. Applies gain multipliers to noise related frequencies.
 */
- (void)removeNoiseFromChannel:(SInt16 *)audioData channel:(UInt32)channelNum withFilteringToken:(int)activeFilteringTokenSeq outputBuffer:(NSMutableData*)outBuffClean{
    // Initialize data for the whole audio processing
    if(activeFilteringTokenSeq != self.filteringTokenSeq){
        return;
    }
    [self runSynchronouslyOnProcessingQueue:^{
        //int cindex = 0;
        SInt16* readPos = audioData;
        
        // Предвычислим квадраты noiseProfile, чтобы сэкономить время в цикле
        float two_scalar = 2.f;
        NSMutableData *squareNoiseProfile = [[NSMutableData alloc] initWithLength:self.spectrumSize * sizeof(float)];
        NSMutableData *twos = [[NSMutableData alloc] initWithLength:self.spectrumSize * sizeof(float)];
        vDSP_vfill(&two_scalar, twos.mutableBytes, 1, self.spectrumSize);
        int ssize = self.spectrumSize;
        vvpowf(squareNoiseProfile.mutableBytes,
               twos.bytes,
               ((float *)self.channelsFrequencySpectrumProfile.mutableBytes) + channelNum * self.spectrumSize,
               &ssize);
        self.spectrumSize = ssize;
        if(activeFilteringTokenSeq != self.filteringTokenSeq){
            return;
        }

        const float *squareNoiseProfileBytes = squareNoiseProfile.mutableBytes;
        // Process audio samples in windows
        while(self.dataLen[channelNum] && self.outSampleCount[channelNum] < self.inSampleCount[channelNum]) {
            // samples available
            int avail = MIN(self.dataLen[channelNum], self.windowSize - self.inputPos[channelNum]);
            // populate FFT input buffer
            vDSP_vflt16(readPos, 2, self.mInWaveBuffer[channelNum]+self.inputPos[channelNum], 1, avail);
            
            readPos += (sizeof(SInt16))*avail;
            self.dataOffset[channelNum] += (sizeof(SInt16))*avail;
            self.dataLen[channelNum] -= avail;
            self.inputPos[channelNum] += avail;
            
            if (self.inputPos[channelNum] == self.windowSize) {
                if(activeFilteringTokenSeq != self.filteringTokenSeq){
                    return;
                }

                [self fillFirstHistoryWindow:channelNum];
                
                // RemoveNoise
                int center = self.historyLen*channelNum + self.historyLen / 2;
                int start = center - self.minSignalBlocks/2;
                int finish = start + self.minSignalBlocks;
                
                // Raise the gain for elements in the center of the sliding history
                for (int j = 0; j < self.spectrumSize; j++) {
                    float min = self.mSpectrums[start][j];
                    for (int i = start+1; i < finish; i++) {
                        if (self.mSpectrums[i][j] < min)
                            min = self.mSpectrums[i][j];
                    }
                    
                    float noiseLevel = squareNoiseProfileBytes[j];
                    if (min > self.sensitivityFactor * noiseLevel && self.mGains[center][j] < 1.0) {
                        self.mGains[center][j] = 1.0;
                    }
                }
                
                // Decay the gain in both directions;
                // note that oneBlockAttackDecay is less than 1.0
                // of linear attenuation per block
                for (int j = 0; j < self.spectrumSize; j++) {
                    for (int i = center + 1; i < self.historyLen; i++) {
                        if (self.mGains[i][j] < self.mGains[i - 1][j] * self.oneBlockAttackDecay)
                            self.mGains[i][j] = self.mGains[i - 1][j] * self.oneBlockAttackDecay;
                        if (self.mGains[i][j] < self.noiseAttenFactor)
                            self.mGains[i][j] = self.noiseAttenFactor;
                    }
                    for (int i = center - 1; i >= 0; i--) {
                        if (self.mGains[i][j] < self.mGains[i + 1][j] * self.oneBlockAttackDecay)
                            self.mGains[i][j] = self.mGains[i + 1][j] * self.oneBlockAttackDecay;
                        if (self.mGains[i][j] < self.noiseAttenFactor)
                            self.mGains[i][j] = self.noiseAttenFactor;
                    }
                }
                
                // Apply frequency smoothing to output gain
                int iout = self.historyLen * channelNum + (self.historyLen - 1);  // end of the queue
                float *tmp = calloc(self.spectrumSize, sizeof(float));
                int i, j, j0, j1;
                
                for(i = 0; i < self.spectrumSize; i++) {
                    j0 = MAX(0, i - self.freqSmoothingBins);
                    j1 = MIN(self.spectrumSize-1, i + self.freqSmoothingBins);
                    tmp[i] = 0.0;
                    for(j = j0; j <= j1; j++) {
                        tmp[i] += self.mGains[iout][j];
                    }
                    tmp[i] = tmp[i]/(j1 - j0 + 1);
                }
                
                for(i = 0; i < self.spectrumSize; i++){
                    self.mGains[iout][i] = tmp[i];
                }
                free(tmp);
                //////////////////////////////////////////////////////////
                
                // Apply gain to FFT
                for (j = 0; j < (self.spectrumSize-1); j++) {
                    self.complex_output.realp[j] = self.mRealFFTs[iout][j] * self.mGains[iout][j];
                    self.complex_output.imagp[j] = self.mImagFFTs[iout][j] * self.mGains[iout][j];
                }
                // The Fs/2 component is stored as the imaginary part of the DC component
                self.complex_output.imagp[0] = self.mRealFFTs[iout][self.spectrumSize-1] * self.mGains[iout][self.spectrumSize-1];
                
                // Inverse FFT to get samples (frequency to time conversion)
                COMPLEX_SPLIT csStruct = self.complex_output;
                vDSP_fft_zrip(self.setup, &(csStruct), 1, 11, kFFTDirection_Inverse);
                self.complex_output = csStruct;
                
                // Scale results (vDSP specific)
                float scale = (float) 1.0 / (2 * self.windowSize);
                vDSP_vsmul(self.complex_output.realp, 1, &scale, self.complex_output.realp, 1, self.windowSize/2);
                vDSP_vsmul(self.complex_output.imagp, 1, &scale, self.complex_output.imagp, 1, self.windowSize/2);
                
                // Get audio samples from complex data
                vDSP_ztoc(&csStruct, 1, (COMPLEX *) self.obtainedReal[channelNum], 2, self.windowSize/2);
                self.complex_output = csStruct;
                
                // Overlap-add
                for(j = 0; j < self.windowSize; j++) {
                    self.outOverlapBuffer[channelNum][j] +=  self.obtainedReal[channelNum][j] * self.hannWindow[j];
                }
                
                // Output the first half of the overlap buffer, they're done -
                // and then shift the next half over.
                if (self.outSampleCount[channelNum] >= 0) {   // ...but not if it's the first half-window
                    // Pointer to the destination bytes (where to write)
                    //ptrdiff_t offset = 2 * self.outSampleCount[channelNum] + channelNum;
                    
                    // Copy the data (float -> UInt16 transformation)
                    //SInt16 *destination = ((SInt16*)self.processedAudioData.mutableBytes) + offset;
                    //vDSP_vfix16(_outOverlapBuffer[channelNum], 1, destination, 2, self.windowSize/2);
                    
                    SInt16 *destination = ((SInt16*)outBuffClean.mutableBytes) + channelNum + 2*self.cleanBytesOffset[channelNum];
                    vDSP_vfix16(self.outOverlapBuffer[channelNum], 1, destination, 2, self.windowSize/2);
                    self.cleanBytesOffset[channelNum] += self.windowSize/2;
                }
                self.outSampleCount[channelNum] += self.windowSize / 2;
                
                for(j = 0; j < self.windowSize / 2; j++) {
                    self.outOverlapBuffer[channelNum][j] =
                    self.outOverlapBuffer[channelNum][j + (self.windowSize / 2)];
                    self.outOverlapBuffer[channelNum][j + (self.windowSize / 2)] = 0.0;
                }
                ////////////////////////////////////////
                
                // RotateHistoryWindows
                [self rotateHistoryWindows:channelNum];
                
                // Rotate halfway for overlap-add
                for(i = 0; i < self.windowSize / 2; i++) {
                    self.mInWaveBuffer[channelNum][i] = self.mInWaveBuffer[channelNum][i + self.windowSize / 2];
                }
                self.inputPos[channelNum] = self.windowSize / 2;
            }
        }
    }];
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

#pragma mark -

- (void)addProcessedSamplesDataWithSampleCount:(SInt16*)readySamples bytesLen:(NSInteger)len {
    
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

- (id <AbstractChannel>)channelAtIndex:(NSInteger)index {
    return nil;
}

- (NSString *)identifierForLogicProviderType:(SWIFT_METATYPE(LogicProvider))type {
    return [NSString stringWithFormat:@"filtered_noise.%@", type];
}

@end
