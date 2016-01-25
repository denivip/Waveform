//
//  DVGAudioProcessor.h
//  Denoise
//
//  Created by Denis Bulichenko on 27/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

#import "DVGAudioAnalyzer.h"

@interface DVGNoiseFilter : DVGAudioAnalyzer

/**
 *  The noise profile calculated for original sound track.
 *  It contains information in the form of a frequency spectrum.
 *  Frequencies present in the spectrum will be surpressed.
 */
@property (nonatomic, readonly, copy) NSArray *oneChannelNoiseProfile;

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
