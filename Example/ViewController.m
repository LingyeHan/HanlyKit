//
//  ViewController.m
//  Example
//
//  Created by 韩灵叶 on 2017/6/23.
//  Copyright © 2017年 Hanlingye. All rights reserved.
//

#import "ViewController.h"
#import <HanlyKit/HanlyKit.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UIButton *addTaskButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    __block NSInteger i1 = 0;
    [[HLTaskScheduler scheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"1 currentThread: %@", [NSThread currentThread]);
        sleep(5);
    } forIdentifier:@"task1"];
    
    __block NSInteger i = 0;
    [[HLTaskScheduler mainThreadScheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"2 currentThread: %@", [NSThread currentThread]);
        self.textLabel.text = [NSString stringWithFormat:@"Main %lu", i++];
    } forIdentifier:@"task2"];
    
    [[HLTaskScheduler scheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"3 currentThread: %@", [NSThread currentThread]);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.label1.text = [NSString stringWithFormat:@"%lu", i1++];
        });
        sleep(1);
    } forIdentifier:@"task1"];
}
- (IBAction)addTask:(id)sender {
    
    NSString *identifier = [NSString stringWithFormat:@"addTask: %u", arc4random()];
    [[HLTaskScheduler mainThreadScheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"Add Task %@", identifier);
    } forIdentifier:identifier];
    
    [[HLTaskScheduler mainThreadScheduler] stopTaskWithIdentifier:@"task2"];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
