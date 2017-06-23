//
//  ViewController.m
//  Example
//
//  Created by 韩灵叶 on 2017/6/23.
//  Copyright © 2017年 Hanlingye. All rights reserved.
//

#import "ViewController.h"
#import "HLTaskScheduler.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [HLTaskScheduler registerTaskWithCompletionHandler:^{
        sleep(2);
        NSLog(@"2currentThread: %@", [NSThread currentThread]);
    }];
    
    [HLTaskScheduler registerTaskWithCompletionHandler:^{
        sleep(5);
        NSLog(@"5currentThread: %@", [NSThread currentThread]);
    }];
    
    [HLTaskScheduler registerTaskWithCompletionHandler:^{
        sleep(3);
        NSLog(@"3currentThread: %@", [NSThread currentThread]);
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
