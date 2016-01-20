//
//  DVGCollectionReusableView.h
//  Denoise
//
//  Created by Sergey Shpygar on 04.12.14.
//  Copyright (c) 2014 DENIVIP Group. All rights reserved.
//

@import UIKit;

@interface DVGCollectionReusableView : UICollectionReusableView

@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subtitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *dateLabel;

@end
