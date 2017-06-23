//
//  HLTaskScheduler.h
//  HanlyKit
//
//  Created by 韩灵叶 on 2017/6/23.
//  Copyright © 2017年 Hanlingye. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, WMTaskSchedulerFetchResult) {
    WMTaskSchedulerFetchResultNewData,
    WMTaskSchedulerFetchResultNoData,
    WMTaskSchedulerFetchResultFailed
};

@interface HLTaskScheduler : NSObject

+ (void)registerTaskWithCompletionHandler:(void (^)(void))completionHandler;

@end
