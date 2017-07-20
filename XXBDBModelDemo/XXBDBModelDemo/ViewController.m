//
//  ViewController.m
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import "ViewController.h"
#import "XXBDBHelper.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [[XXBDBHelper shareDBHelper] changeDefaultDBWithDirectoryName:@"XXB" complate:^(BOOL complate) {
        if (complate) {
            NSLog(@"XXB Complate");
        } else {
            NSLog(@"XXB Not Complate");
        }
    }];
    NSLog(@"XXB Test");
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
