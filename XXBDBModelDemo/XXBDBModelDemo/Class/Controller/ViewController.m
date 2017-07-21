//
//  ViewController.m
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import "ViewController.h"
#import "XXBDBHelper.h"
#import "XXBUserModel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self initDB];
//    [self testSave];
    [self testSaveArray];
}

- (void)initDB {
    [[XXBDBHelper shareDBHelper] changeDefaultDBWithDirectoryName:@"XXB" complate:^(BOOL complate) {
        if (complate) {
            NSLog(@"XXB - DBINIT Complate");
        } else {
            NSLog(@"XXB - DBINIT Not Complate");
        }
    }];
    
}

- (void)testSave {
    XXBUserModel *userModel = [[XXBUserModel alloc] init];
    userModel.name = @"Test Name 1";
    [userModel saveSync];
    NSLog(@"saveSync");
    [userModel saveAsync:^(BOOL complate) {
        NSLog(@"saveAsync");
    }];
    NSArray *array = [XXBUserModel findAllSync];
    NSLog(@"XXB %@",array);
}

- (void)testSaveArray {
    NSMutableArray *saveArray = [NSMutableArray array];
    XXBUserModel *userModel = [[XXBUserModel alloc] init];
    userModel.name = @"Test Name save Array";
    [saveArray addObject:userModel];
    
    [XXBUserModel saveObjectsSync:saveArray];
    NSLog(@"saveSync");
    [XXBUserModel saveObjectsAsync:saveArray complate:^(BOOL complate) {
        NSLog(@"saveAsync");
    }];
    NSArray *searchArray = [XXBUserModel findAllSync];
    NSLog(@"XXB - search Sync %@",searchArray);
    [XXBUserModel findAllAsync:^(NSArray *answerArray) {
        NSLog(@"XXB - search Async %@",answerArray);
    }];
    NSLog(@"XXB - search end");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
