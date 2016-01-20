//
//  DenoiseCollectionViewCell.m
//  Denoise
//
//  Created by Denis Bulichenko on 11/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

#import "DenoiseCollectionViewCell.h"

@interface DenoiseCollectionViewCell ()

@property (nonatomic, strong) CAGradientLayer *gradient;


@end

@implementation DenoiseCollectionViewCell

-(void)awakeFromNib{
    [super awakeFromNib];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = @[(id)[[UIColor clearColor] CGColor],
                        (id)[[UIColor blackColor] CGColor]];
    [self.imageView.layer addSublayer:gradient];
    self.gradient = gradient;
}

-(void)layoutSublayersOfLayer:(CALayer *)layer{
    [super layoutSublayersOfLayer:layer];
    
    self.gradient.frame = CGRectMake( - 1, CGRectGetHeight(self.bounds) - 20, CGRectGetWidth(self.bounds) + 2, 21);
}

- (void)setVideoSource:(PHAsset *)videoSource {
    _videoSource = videoSource;
    
    self.timeLabel.text = [self stringWithTime:videoSource.duration];
    
    static PHCachingImageManager *imageManager = nil;
    if (!imageManager) {
        imageManager = [[PHCachingImageManager alloc] init];
    }
    
    [imageManager requestImageForAsset:videoSource targetSize:self.bounds.size contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        if (self.videoSource == videoSource) { // Cell hasn't been reused
            self.imageView.image = result;
        }
    }];
    
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGSize thumbSize = CGSizeMake(screenSize.width,screenSize.width*(3.0/4.0));
    [imageManager requestImageForAsset:videoSource targetSize:thumbSize contentMode:PHImageContentModeAspectFill options:nil resultHandler:^(UIImage *result, NSDictionary *info) {
        if (self.videoSource == videoSource) { // Cell hasn't been reused
            self.videoThumbnail = result;
        }
    }];
}

- (NSString *)stringWithTime:(NSTimeInterval)time {
    int seconds = (int)time;
    int minutes = seconds/60;
    seconds = seconds%60;
    int hours = minutes/60;
    minutes = minutes%60;
    if (hours) {
        return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
    } else if (minutes) {
        return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"00:%02d", seconds];
    }
}

#pragma mark - 

- (BOOL)isAccessibilityElement {
    return YES;
}

- (NSString *)accessibilityLabel {
    return @"Video";
}

- (UIAccessibilityTraits)accessibilityTraits {
    return UIAccessibilityTraitButton;
}

- (NSString *)accessibilityValue {
    
    int seconds = (int)(_videoSource.duration);
    int minutes = seconds/60;
    seconds     = seconds%60;
    int hours   = minutes/60;
    minutes     = minutes%60;

    if (hours) {
        return [NSString stringWithFormat:@"%d hours %02d minutes %02d seconds", hours, minutes, seconds];
    } else if (minutes) {
        return [NSString stringWithFormat:@"%02d minutes %02d seconds", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02d seconds", seconds];
    }
}

@end
