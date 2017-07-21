//
//  XXBDBHelper.m
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import "XXBDBHelper.h"
#import <objc/runtime.h>
#import <FMDB.h>


static const void * const kXXBDBHelpeDispatchQueueSpecificKey = &kXXBDBHelpeDispatchQueueSpecificKey;

@interface XXBDBHelper ()
{
    NSString  *_defaultDBPath;
}

@property(nonatomic, strong) NSMutableDictionary    *nameFMDBQueueDict;

@property(nonatomic, strong) dispatch_queue_t       helperQueue;


@end

@implementation XXBDBHelper
static id _instance = nil;
+ (instancetype)shareDBHelper {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone {
    if (_instance == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            _instance = [super allocWithZone:zone];
        });
    }
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone {
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self setupData];
        });
    }
    return self;
}

- (void)setupData {
    static NSString *queueName = @"XXBQueueName";
    self.nameFMDBQueueDict = [NSMutableDictionary dictionary];
    self.helperQueue = dispatch_queue_create([queueName UTF8String], NULL);
    dispatch_queue_set_specific(self.helperQueue, [self getDispatchQueueKey], (__bridge void *)self, NULL);
}


- (NSString *)getDBPathWithDBModel:(XXBDBModel *)model {
    return nil;
}

- (FMDatabaseQueue *)getDefaultDBQueue {
    return nil;
}

- (FMDatabaseQueue *)getDatabaseQueueWithClass:(Class)modelClass {
    if ([modelClass respondsToSelector:@selector(getDBPathName)]) {
        return [self addIfNotHaveDBQueueWithName:[modelClass getDBPathName]];
    } else {
        return nil;
    }
}

- (FMDatabaseQueue *)getDatabaseQueueWithDBModel:(XXBDBModel *)model {
    return [self getDatabaseQueueWithClass:[model class]];
}

- (void)changeDefaultDBWithDirectoryName:(NSString *)name complate:(XXBDBComplate)complate {
    if (name.length == 0) {
        complate(NO);
        return;
    }
    dispatch_async(XXBDBHelperQueue, ^{
        if (self.defaultDBPath != nil) {
#warning 需要移除  FMDBQueue
        }
        self.defaultDBPath = name;
        [self addIfNotHaveDBQueueWithName:name];
        
        int numClasses;
        Class *classes = NULL;
        numClasses = objc_getClassList(NULL,0);
        
        if ( numClasses >0 ) {
            classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
            numClasses = objc_getClassList(classes, numClasses);
            for (int i = 0; i < numClasses; i++) {
                if ( class_getSuperclass(classes[i]) == [XXBDBModel class] ) {
                    id class = classes[i];
                    if ([class getDBPathName] == nil || [class getDBPathName].length == 0) {
                        [class performSelector:@selector(createTable) withObject:nil];
                    } else {
                        //单独创建数据库的都不处理
                    }
                }
            }
            free(classes);
        }
        complate(YES);
    });
}

- (void)changeDBWithDBModel:(XXBDBModel *)model complate:(XXBDBComplate)complate {
    dispatch_async([self getBDBHelperQueue], ^{
        [self addIfNotHaveDBQueueWithName:[[model class] getDBPathName]];
        [[model class] performSelector:@selector(createTable) withObject:nil];
        complate(YES);
    });
    
}

#pragma mark - DBCREAT

- (FMDatabaseQueue *)addIfNotHaveDBQueueWithName:(NSString *)name {
    if (name.length == 0) {
        name = self.defaultDBPath;
    }
    FMDatabaseQueue *dbQueue = [self.nameFMDBQueueDict valueForKey:name];
    if (dbQueue == nil) {
        NSString *path = [self dbPathWithDirectoryName:name];
        dbQueue = [FMDatabaseQueue databaseQueueWithPath:path];
        [self.nameFMDBQueueDict setObject:dbQueue forKey:name];
    }
    return dbQueue;
}


- (NSString *)dbPathWithDirectoryName:(NSString *)directoryName {
    NSString *docsdir = [NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSFileManager *filemanage = [NSFileManager defaultManager];
    if (directoryName == nil || directoryName.length == 0) {
        docsdir = [docsdir stringByAppendingPathComponent:@"XXBDB"];
    } else {
        docsdir = [docsdir stringByAppendingPathComponent:directoryName];
    }
    BOOL isDir;
    BOOL exit =[filemanage fileExistsAtPath:docsdir isDirectory:&isDir];
    if (!exit || !isDir) {
        [filemanage createDirectoryAtPath:docsdir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *dbpath = [docsdir stringByAppendingPathComponent:@"XXB.sqlite"];
    return dbpath;
}

#pragma mark - Dispatch
- (dispatch_queue_t)getBDBHelperQueue {
    return self.helperQueue;
}

- (const void * const)getDispatchQueueKey {
    return kXXBDBHelpeDispatchQueueSpecificKey;
}

- (void)judjeCurrentQueueSame {
#ifndef NDEBUG
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    XXBDBHelper *currentHelper = (__bridge id)dispatch_get_specific([self getDispatchQueueKey]);
    assert(currentHelper == self && "数据存取不在同一个队列里边 肯呢个会引起数据混乱，崩溃");
#endif
}

- (void)judjeCurrentQueueDifferent {
#ifndef NDEBUG
    /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
     * and then check it against self to make sure we're not about to deadlock. */
    XXBDBHelper *currentHelper = (__bridge id)dispatch_get_specific([self getDispatchQueueKey]);
    assert(currentHelper != self && "数据存取在同一个队列里边，可能会造成线程的死锁");
#endif
}

- (BOOL)isInXXBDBHelperQueue {
    XXBDBHelper *currentHelper = (__bridge id)dispatch_get_specific([self getDispatchQueueKey]);
    if (currentHelper == self) {
        return YES;
    } else {
        return NO;
    }
}
@end
