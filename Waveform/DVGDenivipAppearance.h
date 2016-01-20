//
//  DVGDenivipAppearance.h
//  Denoise
//
//  Created by Sergey Shpygar on 02.12.14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

@import UIKit;

@interface DVGDenivipAppearance : NSObject

+ (void)configureAppearanceForClass:(Class)customClass;

@end


@interface UIColor (DVGDenivipAppearance)

+ (UIColor *)denivipBackgroundColor;
+ (UIColor *)denivipHighlightedColor;
+ (UIColor *)denivipGrayColor;
+ (UIColor *)denivipPrecsColor;

+ (UIColor *)denivipTintColor;
+ (UIColor *)denivipBarTintColor;

@end

@interface UIImage (DVGDenivipAppearance)

+ (UIImage *)imageWithColor:(UIColor *)color;

@end