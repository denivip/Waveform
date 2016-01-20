//
//  DVGDenivipAppearance.m
//  Denoise
//
//  Created by Sergey Shpygar on 02.12.14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//


#import "DVGDenivipAppearance.h"
@import UIKit;

@implementation DVGDenivipAppearance

+ (void)configureAppearanceForClass:(Class)customClass
{
    [[UINavigationBar appearanceWhenContainedIn:customClass, nil] setBarTintColor:[UIColor denivipBarTintColor]];
    [[UINavigationBar appearanceWhenContainedIn:customClass, nil] setTintColor:[UIColor denivipTintColor]];
    
    NSDictionary * navBarTitleTextAttributes =
    @{ NSForegroundColorAttributeName : [UIColor whiteColor],
       //     NSShadowAttributeName          : shadow,
       NSFontAttributeName            : [UIFont fontWithName:@"Avenir Next" size:17.0] };
    
    [[UINavigationBar appearance] setTitleTextAttributes:navBarTitleTextAttributes];
    
    [[UIProgressView appearanceWhenContainedIn:customClass, nil] setTrackTintColor:[UIColor colorWithWhite:1.f alpha:0.3f]];
    [[UIProgressView appearanceWhenContainedIn:customClass, nil] setProgressTintColor:[UIColor denivipTintColor]];
    
    [[UISlider appearance] setMinimumTrackTintColor:[UIColor denivipTintColor]];
}

@end


@implementation UIColor (DVGDenivipAppearance)

+ (UIColor *)denivipBackgroundColor
{
    return [UIColor colorWithRed:46.f/255.f green:55.f/255.f blue:63.f/255.f alpha:1.f];
}

+ (UIColor *)denivipTintColor
{
    return [UIColor whiteColor];
}

+ (UIColor *)denivipGrayColor{
    return [UIColor colorWithRed:66.f/255.f green:65.f/255.f blue:77.f/255.f alpha:1.f];
}

+ (UIColor *)denivipPrecsColor{
    //return [UIColor colorWithRed:255.f/255.f green:55.f/255.f blue:22/255.f alpha:1.f];
    return [UIColor denivipGrayColor];
}

+ (UIColor *)denivipBarTintColor
{
    return [UIColor colorWithRed:27.f/255.f green:33.f/255.f blue:37.f/255.f alpha:0.9f];
}

+ (UIColor *)denivipHighlightedColor
{
    return [UIColor colorWithRed:48.f/255.f green:237.f/255.f blue:170.f/255.f alpha:1.f];
}

@end

@implementation UIImage (DVGDenivipAppearance)

+ (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

@end

