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
#define HLLogV(...) NSLog(@"%s(%p) %@", __PRETTY_FUNCTION__, self, [NSString stringWithFormat:__VA_ARGS__])
#define HLLogD(...) NSLog(__VA_ARGS__)
#else
#define HLLogD(...)
#endif

NSString * const kHLTaskSchedulerCurrentSchedulerKey = @"HLTaskSchedulerCurrentSchedulerKey";

#ifdef DEBUG
static CGFloat const kHLTaskSchedulerIntervalTime = 5.0f;
#else
static CGFloat const kHLTaskSchedulerIntervalTime = 60.0f;
#endif

@interface HLTask : NSObject <NSCopying>

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) void (^completionBlock)();
@property(nonatomic, getter=isEnabled) BOOL enabled;

- (instancetype)initWithCompletionBlock:(void (^)(void))completionBlock identifier:(NSString *)identifier;

@end

@implementation HLTask

- (instancetype)initWithCompletionBlock:(void (^)(void))completionBlock identifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        self.identifier = [identifier copy];
        self.completionBlock = [completionBlock copy];
        self.enabled = YES;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    id copy = [[[self class] alloc] init];
    if (copy) {
        [copy setIdentifier:[self.identifier copyWithZone:zone]];
        [copy setEnabled:self.isEnabled];
    }
    
    return copy;
}

- (BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (!object || ![object isKindOfClass:[self class]]) return NO;
    if (![(id)[self identifier] isEqual:[object identifier]]) return NO;
    
    return YES;
}

- (NSUInteger)hash {
    return [self.identifier hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"task: %@, enabled: %@",
            self.identifier,
            (self.isEnabled ? @"true" : @"false")];
}

@end

@interface HLTaskScheduler ()

@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) dispatch_source_t timer;

@property (nonatomic, copy)     NSString *name;
@property (nonatomic, strong)   NSMutableOrderedSet<HLTask *> *tasks;

@end

@implementation HLTaskScheduler

#pragma mark - NSObject

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.name];
}

#pragma mark - Lifecycle

- (void)dealloc {
    [self destroyTimer];
    [self removeAllTasks];
    if (_tasks) {
        _tasks = nil;
    }
    if (_queue != NULL) {
        _queue = NULL;
    }
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
        self.tasks = [NSMutableOrderedSet new];
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
    self = [self init];
    
    dispatch_queue_t queue = NULL;
    if (targetQueue) {
        queue = targetQueue;
    } else {
        queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_CONCURRENT);
    }
    _name = name ? [name copy] : [NSString stringWithFormat:@"org.hanly.Scheduler(%s)", dispatch_queue_get_label(queue)];
    _queue = queue;
    
    [self start];
    [self registerNotification];
    
    return self;
}

- (void)registerNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(start)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(stop)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

#pragma mark - Scheduler Public Methods

+ (instancetype)scheduler {
    static dispatch_once_t onceToken;
    static HLTaskScheduler *scheduler;
    dispatch_once(&onceToken, ^{
        scheduler = [[HLTaskScheduler alloc] initWithName:@"org.hanly.task.Scheduler" targetQueue:NULL];
    });
    return scheduler;
}

+ (instancetype)mainThreadScheduler {
    static dispatch_once_t onceToken;
    static HLTaskScheduler *mainThreadScheduler;
    dispatch_once(&onceToken, ^{
        mainThreadScheduler = [[HLTaskScheduler alloc] initWithName:@"org.hanly.task.Scheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
    });
    
    return mainThreadScheduler;
}

- (void)registerTaskWithCompletionHandler:(void (^)(void))completionHandler forIdentifier:(NSString *)identifier {
    [self removeTaskForIdentifier:identifier];
    [self addTaskWithCompletionBlock:completionHandler forIdentifier:identifier];
}

- (void)start {
    NSLog(@"Task Scheduler Started");
    
    [self destroyTimer];
    [self createTimer];
    dispatch_resume(self.timer);
}

- (void)stop {
    NSLog(@"Task Scheduler Stopped");

    [self destroyTimer];
}

- (void)reset {
    NSLog(@"Task Scheduler Reset");
    [self stop];
    [self removeAllTasks];
}

- (void)startTaskWithIdentifier:(NSString *)identifier {
    NSLog(@"Task Scheduler `%@` task enabled", identifier);
    
    [self.tasks enumerateObjectsUsingBlock:^(HLTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([task.identifier isEqualToString:identifier]) {
            task.enabled = YES;
            *stop = YES;
        }
    }];
}

- (void)stopTaskWithIdentifier:(NSString *)identifier {
    NSLog(@"Task Scheduler `%@` task disabled", identifier);
    
    [self.tasks enumerateObjectsUsingBlock:^(HLTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([task.identifier isEqualToString:identifier]) {
            task.enabled = NO;
            *stop = YES;
        }
    }];
}

#pragma mark - Private Methods

- (void)createTimer {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, 0), (uint64_t)kHLTaskSchedulerIntervalTime * NSEC_PER_SEC, DISPATCH_TIME_FOREVER * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
//        HLLogD(@"%@", self);
        [self performCurrentScheduler];
    });
}

- (void)performCurrentScheduler {
    NSArray<HLTask *> *tasks = [self copyAllTasks];
    
    __weak typeof(self) wSelf = self;
    for (HLTask *task in tasks) {
        if (!task.isEnabled) {
            continue;
        }
        dispatch_async(self.queue, ^{//dispatch_get_main_queue() 在主线程执行会导致切换前后台不执行系统通告
            __strong typeof(wSelf) self = wSelf;
            HLLogD(@"Perform Task %@", task);
            [self performBlock:task.completionBlock];
        });
    }
}

- (void)performBlock:(void (^)(void))block {
    NSParameterAssert(block != NULL);
    
    @autoreleasepool {
        block();
    }
}

- (NSArray<HLTask *> *)copyAllTasks {
    NSArray<HLTask *> *copyTasks = nil;
    @synchronized (self) {
        copyTasks = [NSArray arrayWithArray:self.tasks.array];
    }
    return copyTasks;
}

- (void)addTaskWithCompletionBlock:(void (^)(void))block forIdentifier:(NSString *)identifier {
    NSParameterAssert(block != nil);
    
    @synchronized (self) {
        HLTask *task = [[HLTask alloc] initWithCompletionBlock:block identifier:identifier];
        [self.tasks addObject:task];
    }
}

- (void)removeTaskForIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier != nil);
    
    @synchronized (self) {
        HLLogD(@"Remove `%@` Task", identifier);
        HLTask *task = [[HLTask alloc] initWithCompletionBlock:nil identifier:identifier];
        [self.tasks removeObject:task];
    }
}

- (void)removeAllTasks {
    @synchronized (self) {
        [self.tasks removeAllObjects];
    }
}

#pragma mark - Class Methods

@end
