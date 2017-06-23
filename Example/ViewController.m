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
        NSLog(@"2currentThread: %@", [NSThread currentThread]);
        sleep(5);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.label1.text = [NSString stringWithFormat:@"%lu", i1++];
        });
        
    }];
    
    __block NSInteger i = 0;
    [[HLTaskScheduler mainThreadScheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"5currentThread: %@", [NSThread currentThread]);
        self.textLabel.text = [NSString stringWithFormat:@"Main %lu", i++];
    }];
    
    [[HLTaskScheduler scheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"3currentThread: %@", [NSThread currentThread]);
        sleep(1);
    }];
}
- (IBAction)addTask:(id)sender {
    
    [[HLTaskScheduler mainThreadScheduler] registerTaskWithCompletionHandler:^{
        NSLog(@"addTask: %u", arc4random());
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
