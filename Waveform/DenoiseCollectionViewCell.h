//
//  DenoiseCollectionViewCell.h
//  Denoise
//
//  Created by Denis Bulichenko on 11/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

@import UIKit;
@import Photos;

@interface DenoiseCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UILabel *timeLabel;

@property (nonatomic, strong) PHAsset *videoSource;
@property (nonatomic, strong) UIImage *videoThumbnail;
@end
