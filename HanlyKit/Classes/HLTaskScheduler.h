//
//  HLTaskScheduler.h
//  HanlyKit
//
//  Created by 韩灵叶 on 2017/6/23.
//  Copyright © 2017年 Hanlingye. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HLTaskScheduler : NSObject

+ (instancetype)scheduler;

+ (instancetype)mainThreadScheduler;

- (void)registerTaskWithCompletionHandler:(void (^)(void))completionHandler forIdentifier:(NSString *)identifier;

- (void)start;

- (void)stop;

- (void)reset;

- (void)startTaskWithIdentifier:(NSString *)identifier;

- (void)stopTaskWithIdentifier:(NSString *)identifier;

@end
