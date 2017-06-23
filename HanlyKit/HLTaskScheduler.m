//
//  HLTaskScheduler.m
//  HanlyKit
//
//  Created by 韩灵叶 on 2017/6/23.
//  Copyright © 2017年 Hanlingye. All rights reserved.
//

#import "HLTaskScheduler.h"
#import <UIKit/UIKit.h>

#ifndef HL_ENABLE_LOGGING
#ifdef DEBUG
#define HL_ENABLE_LOGGING 1
#else
#define HL_ENABLE_LOGGING 0
#endif
#endif

#if HL_ENABLE_LOGGING != 0
#define HLLog(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#endif

NSString * const kHLTaskSchedulerCurrentSchedulerKey = @"HLTaskSchedulerCurrentSchedulerKey";

static CGFloat const kWMTaskExecuteTimeout = 30.0f;

@interface HLTaskScheduler ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_source_t timer;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableArray *completionBlocks;

@end

@implementation HLTaskScheduler

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.name];
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self removeCompletionBlocks];
    if (_completionBlocks) {
        _completionBlocks = nil;
    }
    if (_queue != NULL) {
        _queue = NULL;
    }
    [self destroyTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)destroyTimer {
    if (_timer) {
        dispatch_source_cancel(_timer);
        _timer = NULL;
    }
}

#pragma mark - Initializers

- (instancetype)init {
    self = [super init];
    if (self) {
        self.completionBlocks = [NSMutableArray new];
        [self registerNotification];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
    self = [self init];
    
    dispatch_queue_t queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
    if (targetQueue) {
        dispatch_set_target_queue(queue, targetQueue);
    }
    _name = name ? [name copy] : [NSString stringWithFormat:@"org.hanly.queue.task.Scheduler(%s)", dispatch_queue_get_label(queue)];
    _queue = queue;
    
//    [self startTimer];
//    [self registerNotification];
    
    return self;
}

- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startTimer)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stopTimer)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

#pragma mark - Scheduler Public Methods

+ (instancetype)scheduler {
    static dispatch_once_t onceToken;
    static HLTaskScheduler *scheduler;
    dispatch_once(&onceToken, ^{
        scheduler = [[HLTaskScheduler alloc] initWithName:@"org.hanly.queue.task.Scheduler" targetQueue:NULL];
    });
    return scheduler;
}

+ (instancetype)mainThreadScheduler {
    static dispatch_once_t onceToken;
    static HLTaskScheduler *mainThreadScheduler;
    dispatch_once(&onceToken, ^{
        mainThreadScheduler = [[HLTaskScheduler alloc] initWithName:@"org.hanly.queue.task.Scheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
    });
    
    return mainThreadScheduler;
}

+ (void)registerTaskWithCompletionHandler:(void (^)(void))completionHandler {
    HLTaskScheduler *scheduler = [HLTaskScheduler scheduler];
    
    [scheduler addCompletionBlock:completionHandler];
}

- (void)startTimer {
    dispatch_resume(self.timer);
}

- (void)stopTimer {
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), self.queue, ^{
        dispatch_suspend(self.timer);
//    });
}

- (void)createTimer {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.timer, DISPATCH_TIME_NOW, 3.f * NSEC_PER_SEC, DISPATCH_TIME_FOREVER * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        NSLog(@"come timer");
    });
    dispatch_resume(self.timer);
}

- (void)updateTimer:(NSDate *)date interval:(NSTimeInterval)interval {
    NSCParameterAssert(date != nil);
    NSCParameterAssert(interval > 0.0 && interval < INT64_MAX / NSEC_PER_SEC);
    
    dispatch_time_t startTime = dispatch_time(DISPATCH_TIME_NOW, interval);//[self.class wallTimeWithDate:date];
    uint64_t intervalInNanoSecs = (uint64_t)(interval * NSEC_PER_SEC);
    
    dispatch_source_set_timer(self.timer, startTime, intervalInNanoSecs, DISPATCH_TIME_FOREVER * NSEC_PER_SEC);
}

- (void)reset {
    [self removeCompletionBlocks];
}

#pragma mark - Private Methods

- (void)performCurrentScheduler {
    NSArray *blocks = nil;
    @synchronized (self) {
        blocks = [NSArray arrayWithArray:self.completionBlocks];
    }
    
    __weak typeof(self) wSelf = self;
    for (void (^block)(void) in blocks) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(wSelf) self = wSelf;
            [self performBlock:block];
        });
    }
    
}

- (void)performBlock:(void (^)(void))block {
    NSCParameterAssert(block != NULL);
    
//    HLTaskScheduler *previousScheduler = [HLTaskScheduler currentScheduler];
//    NSThread.currentThread.threadDictionary[kHLTaskSchedulerCurrentSchedulerKey] = self;
    
    @autoreleasepool {
        block();
    }
    
//    if (previousScheduler) {
//        NSThread.currentThread.threadDictionary[kHLTaskSchedulerCurrentSchedulerKey] = previousScheduler;
//    } else {
//        [NSThread.currentThread.threadDictionary removeObjectForKey:kHLTaskSchedulerCurrentSchedulerKey];
//    }
}

- (void)addCompletionBlock:(void (^)(void))block {
    @synchronized (self) {
        [self.completionBlocks addObject:[block copy]];
    }
}

- (void)removeCompletionBlocks {
    @synchronized (self) {
        [self.completionBlocks removeAllObjects];
    }
}

- (dispatch_source_t)timer {
    if (!_timer) {
        
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
        if (_timer != NULL) {
            dispatch_source_set_event_handler(_timer, ^{
                [self performCurrentScheduler];
            });
            
            [self updateTimer:[NSDate dateWithTimeIntervalSince1970:3] interval:3];
        }
    }
    return _timer;
}

#pragma mark - Class Methods

+ (dispatch_time_t)wallTimeWithDate:(NSDate *)date {
    NSCParameterAssert(date != nil);
    
    double seconds = 0;
    double frac = modf(date.timeIntervalSince1970, &seconds);
    
    struct timespec walltime = {
        .tv_sec = (time_t)fmin(fmax(seconds, LONG_MIN), LONG_MAX),
        .tv_nsec = (long)fmin(fmax(frac * NSEC_PER_SEC, LONG_MIN), LONG_MAX)
    };
    
    return dispatch_walltime(&walltime, 0);
}

+ (HLTaskScheduler *)currentScheduler {
    HLTaskScheduler *scheduler = NSThread.currentThread.threadDictionary[kHLTaskSchedulerCurrentSchedulerKey];
    if (scheduler) {
        return scheduler;
    }
    if ([NSThread isMainThread]) {
        return HLTaskScheduler.mainThreadScheduler;
    }
    
    return nil;
}

@end
