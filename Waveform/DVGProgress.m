//
//  DVGProgress.m
//  Denoise
//
//  Created by developer on 07/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

#import "DVGProgress.h"

@interface DVGProgress ()

@end

@implementation DVGProgress

+ (instancetype)__discreteProgressWithTotalUnitCount:(int64_t)unitCount {
    DVGProgress *progress = [[DVGProgress alloc] initWithParent:nil userInfo:nil];
    progress.totalUnitCount = unitCount;
    return progress;
}

- (instancetype)initWithParent:(nullable NSProgress *)parentProgressOrNil userInfo:(nullable NSDictionary *)userInfoOrNil {
    if (self = [super initWithParent:parentProgressOrNil userInfo:userInfoOrNil]) {
        self.liveContext = @{}.mutableCopy;
        [self addObserver:self
               forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                  options:NSKeyValueObservingOptionNew
                  context:nil];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:NSStringFromSelector(@selector(fractionCompleted))];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    if (self.fractionCompletedChangeHandler != nil) {
        self.fractionCompletedChangeHandler(self.fractionCompleted);
    }
    
    if (self.completedUnitCount == self.totalUnitCount) {
        if (self.completionHandler != nil) {
            if (_error != nil)
                self.completionHandler(NO, _error);
            else
                self.completionHandler(YES, nil);
        }
    }
}

- (void)completeWithError:(NSError *)error {
    self.isCompleted = YES;
    self.error = error;
    self.completedUnitCount = self.totalUnitCount;
}

@end
