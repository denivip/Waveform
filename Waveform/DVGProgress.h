//
//  DVGProgress.h
//  Denoise
//
//  Created by developer on 07/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

@import Foundation;

@interface DVGProgress : NSProgress
@property (nonatomic, copy) void(^completionHandler)(BOOL completed, NSError *error);
@property (nonatomic, copy) void(^fractionCompletedChangeHandler)(double fractionCompleted);
@property (atomic, strong) NSMutableDictionary* liveContext;
@property (atomic, strong) NSError *error;
@property (atomic, assign) BOOL isCompleted;
@property (atomic, strong) NSString* userDescription;
+ (instancetype)__discreteProgressWithTotalUnitCount:(int64_t)unitCount;
- (void)completeWithError:(NSError *)error;
@end
