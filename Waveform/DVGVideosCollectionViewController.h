//
//  DenoiseVideosViewControllerCollectionViewController.h
//  Denoise
//
//  Created by Denis Bulichenko on 11/11/14.
//  Copyright (c) 2014 Denis Bulichenko. All rights reserved.
//

//#import "DVGSnapshotToVideoNoiseTransitionController.h"
#import "DVCollectionViewController.h"

@import UIKit;

@interface DVGVideosCollectionViewController : DVCollectionViewController //<DVGSnapshotToVideoNoiseTransitionProtocol>

@property (strong, nonatomic, readonly) UIView *selectedSnapshotView;

@end
