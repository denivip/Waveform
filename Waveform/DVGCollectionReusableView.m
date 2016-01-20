//
//  DVGCollectionReusableView.m
//  Denoise
//
//  Created by Sergey Shpygar on 04.12.14.
//  Copyright (c) 2014 DENIVIP Group. All rights reserved.
//

#import "DVGCollectionReusableView.h"

@interface DVGCollectionReusableView ()

@end

@implementation DVGCollectionReusableView

-(void)awakeFromNib{
    [super awakeFromNib];
    
    self.titleLabel.adjustsFontSizeToFitWidth =
    self.subtitleLabel.adjustsFontSizeToFitWidth =
    self.dateLabel.adjustsFontSizeToFitWidth = YES;
    
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.dateLabel.text = nil;
}

-(void)prepareForReuse{
    [super prepareForReuse];
    
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.dateLabel.text = nil;
}

-(void)layoutSubviews{
    [super layoutSubviews];

    CGFloat offset = 5;
    
    if (!self.subtitleLabel.text) {
        [self.titleLabel setFrame:CGRectMake(offset, offset, CGRectGetWidth(self.bounds) - 100 - offset, CGRectGetHeight(self.bounds) - 2 * offset)];
        [self.dateLabel setFrame:CGRectMake(CGRectGetWidth(self.bounds) - 100,  offset, 100 - offset, CGRectGetHeight(self.bounds) - 2 * offset )];
    }
    else{
        [self.titleLabel setFrame:CGRectMake(offset, offset, CGRectGetWidth(self.bounds) - 100 - offset, CGRectGetHeight(self.bounds) * 0.6f)];
        [self.subtitleLabel setFrame:CGRectMake(offset, CGRectGetHeight(self.bounds) * 0.6f - offset, CGRectGetWidth(self.bounds) - 100 - offset, CGRectGetHeight(self.bounds) * 0.4f - offset)];
        [self.dateLabel setFrame:CGRectMake(CGRectGetWidth(self.bounds) - 100,  offset, 100 - offset, CGRectGetHeight(self.bounds) * 0.6f )];
}

}

- (BOOL)isAccessibilityElement {
    return YES;
}

- (UIAccessibilityTraits)accessibilityTraits {
    return UIAccessibilityTraitHeader;
}

- (NSString *)accessibilityValue {
    return [NSString stringWithFormat:@"Video collection: %@, %@, %@",
            self.titleLabel.text    ?: @"",
            self.subtitleLabel.text ?: @"",
            self.dateLabel.text     ?: @""];
}

@end
