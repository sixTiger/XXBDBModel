//
//  XXBDBLogUtil.h
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>

#define XXBDBDEFINE_LOG_LEVEL ([[XXBDBLogUtil sharedXXBDBLogUtil] getLogLevel])

#define XXBDBSetLogLevel(level) ([[XXBDBLogUtil sharedXXBDBLogUtil] setLogLevel:level])

#define XXBDBLog(level,fmt, ...) ( \
(XXBDBDEFINE_LOG_LEVEL>level) ? : \
NSLog((@"[XXBDBLog][INFO]--%s[Line%d]--" fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__) \
)

#define XXBDBLogInfo XXBDBLog(XXBDBLogLevelInfo,"")
#define XXBDBLogInfoFmort(fmt, ...) XXBDBLog(XXBDBLogLevelInfo,fmt,##__VA_ARGS__)

typedef enum : int {
    XXBDBLogLevelDebug = 100,
    XXBDBLogLevelInfo = 101,
    XXBDBLogLevelRelease = 102,
    XXBDBLogLevelNone = 0x7fffffff,
} XXBDBLogLevel;

@interface XXBDBLogUtil : NSObject

+ (instancetype)sharedXXBDBLogUtil;

- (void)setLogLevel:(int)aLevel;

- (int)getLogLevel;
@end
