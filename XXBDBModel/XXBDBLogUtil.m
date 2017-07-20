//
//  XXBDBLogUtil.m
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import "XXBDBLogUtil.h"

@interface XXBDBLogUtil ()

@property(nonatomic, assign) int level;
@end

@implementation XXBDBLogUtil
static id _instance = nil;
+ (instancetype)sharedXXBDBLogUtil {
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
        [self initDefaultData];
    }
    return self;
}

- (void)initDefaultData {
    [self setLogLevel:XXBDBLogLevelDebug];
}

- (void)setLogLevel:(int)aLevel {
    _level = aLevel;
}

- (int)getLogLevel {
    return _level;
}
@end
