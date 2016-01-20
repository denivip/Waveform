//
//  DVCollectionViewController.m
//  Denoise
//
//  Created by Sergey Shpygar on 08.12.14.
//  Copyright (c) 2014 DENIVIP Group. All rights reserved.
//

#import "DVCollectionViewController.h"

@interface DVCollectionViewController ()

@end

@implementation DVCollectionViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

-(void)viewDidLoad{
    [super viewDidLoad];
    self.titleScreen = self.titleScreen ?: (self.title ?: NSStringFromClass(self.class));
}

-(BOOL)shouldAutorotate{
    return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskPortrait;
}

@end
