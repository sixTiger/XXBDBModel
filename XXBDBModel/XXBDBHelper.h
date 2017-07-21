//
//  XXBDBHelper.h
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XXBDBModel.h"

@class FMDatabaseQueue;

#define XXBDBHelpJudjeQueueSame [[XXBDBHelper shareDBHelper] judjeCurrentQueueSame]
#define XXBDBHelpJudjeQueueDifferent [[XXBDBHelper shareDBHelper] judjeCurrentQueueDifferent]
#define XXBDBHelperIsInHelperQueue [[XXBDBHelper shareDBHelper] isInXXBDBHelperQueue]
#define XXBDBHelperIsInMainThread [[NSThread currentThread] isMainThread]
#define XXBDBHelperQueue [[XXBDBHelper shareDBHelper] getBDBHelperQueue]


@interface XXBDBHelper : NSObject
+ (instancetype)shareDBHelper;

/*
 * Document目录的下一集目录
 */
@property(nonatomic, copy) NSString  *defaultDBPath;


- (NSString *)getDBPathWithDBModel:(XXBDBModel *)model;
- (FMDatabaseQueue *)getDefaultDBQueue;
- (FMDatabaseQueue *)getDatabaseQueueWithClass:(Class)modelClass;
- (FMDatabaseQueue *)getDatabaseQueueWithDBModel:(XXBDBModel *)model;
- (void)changeDefaultDBWithDirectoryName:(NSString *)name complate:(XXBDBComplate)complate;
- (void)changeDBWithDBModel:(XXBDBModel *)model complate:(XXBDBComplate)complate;


- (dispatch_queue_t)getBDBHelperQueue;
- (const void * const)getDispatchQueueKey;
- (void)judjeCurrentQueueSame;
- (void)judjeCurrentQueueDifferent;
- (BOOL)isInXXBDBHelperQueue;
@end
