//
//  DVGAudioProcessor.h
//  Denoise
//
//  Created by Denis Bulichenko on 27/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

@import Foundation;
@import CoreMedia;
@import AVFoundation;

#import "DVGProgress.h"
#import "Waveform-Swift.h"

@interface DVGNoiseFilter : NSObject
//<ChannelSource>// DVGAudioAnalyzer

/**
 *  The noise profile calculated for original sound track.
 *  It contains information in the form of a frequency spectrum.
 *  Frequencies present in the spectrum will be surpressed.
 */
@property (nonatomic, readonly, copy) NSArray *oneChannelNoiseProfile;
@property (nonatomic) AudioStreamBasicDescription audioFormat;
@property (nonatomic) float* frequencySpectrum;
@property (nonatomic, strong) NSMutableData *channelsFrequencySpectrumProfile;
@property (nonatomic, assign) NSInteger samplesCountInChannel;
@property (atomic) float processedData;

/**
 *  Filters PCM data according to the previously analyzed spectrum
 *
 *  Filtered audio samples are stored in cleanAudioData property
 */
- (DVGProgress *) filterAnalyzedAudio;
- (void) cancelPreviousFiltering;

/**
 *  Saves video into url provided
 */
- (void)saveVideoToURL:(NSURL *)videoURL
     completionHandler:(void (^)(BOOL completed,
                                 NSError *error))completionHandler;

@end
