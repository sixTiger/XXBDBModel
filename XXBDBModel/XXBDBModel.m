//
//  XXBDBModel.m
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import "XXBDBModel.h"
#import <objc/runtime.h>
#import "XXBDBHelper.h"
#import "XXBDBLogUtil.h"
#import <FMDB.h>


@implementation XXBDBModel

/*
 *  如果需要单独设置数据的位置的话需要单独写这个接口
 */
+ (NSString *)getDBPathName {
    return nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSDictionary *dic = [self.class getAllProperties];
        _columeNames = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"name"]];
        _columeTypes = [[NSMutableArray alloc] initWithArray:[dic objectForKey:@"type"]];
    }
    
    return self;
}

#pragma mark - base method
/**
 *  获取该类的所有属性
 */
+ (NSDictionary *)getPropertys {
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    NSArray *theTransients = [[self class] transients];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        //获取属性名
        NSString *propertyName = [NSString stringWithCString:property_getName(property) encoding:NSUTF8StringEncoding];
        if ([theTransients containsObject:propertyName]) {
            continue;
        }
        [proNames addObject:propertyName];
        //获取属性类型等参数
        NSString *propertyType = [NSString stringWithCString: property_getAttributes(property) encoding:NSUTF8StringEncoding];
        /*
         各种符号对应类型，部分类型在新版SDK中有所变化，如long 和long long
         c char         C unsigned char
         i int          I unsigned int
         l long         L unsigned long
         s short        S unsigned short
         d double       D unsigned double
         f float        F unsigned float
         q long long    Q unsigned long long
         B BOOL
         @ 对象类型 //指针 对象类型 如NSString 是@“NSString”
         
         
         64位下long 和long long 都是Tq
         SQLite 默认支持五种数据类型TEXT、INTEGER、REAL、BLOB、NULL
         因为在项目中用的类型不多，故只考虑了少数类型
         */
        if ([propertyType hasPrefix:@"T@\"NSString\""]) {
            [proTypes addObject:SQLTEXT];
        } else if ([propertyType hasPrefix:@"T@\"NSData\""]) {
            [proTypes addObject:SQLBLOB];
        } else if ([propertyType hasPrefix:@"Ti"]||[propertyType hasPrefix:@"TI"]||[propertyType hasPrefix:@"Ts"]||[propertyType hasPrefix:@"TS"]||[propertyType hasPrefix:@"TB"]||[propertyType hasPrefix:@"Tq"]||[propertyType hasPrefix:@"TQ"]) {
            [proTypes addObject:SQLINTEGER];
        } else {
            [proTypes addObject:SQLREAL];
        }
        
    }
    free(properties);
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 获取所有属性，包含主键pk */
+ (NSDictionary *)getAllProperties {
    NSDictionary *dict = [self.class getPropertys];
    
    NSMutableArray *proNames = [NSMutableArray array];
    NSMutableArray *proTypes = [NSMutableArray array];
    [proNames addObject:primaryId];
    [proTypes addObject:[NSString stringWithFormat:@"%@ %@",SQLINTEGER,PrimaryKey]];
    [proNames addObjectsFromArray:[dict objectForKey:@"name"]];
    [proTypes addObjectsFromArray:[dict objectForKey:@"type"]];
    
    return [NSDictionary dictionaryWithObjectsAndKeys:proNames,@"name",proTypes,@"type",nil];
}

/** 数据库中是否存在表 */
+ (BOOL)isExistInTable {
    __block BOOL res = NO;
    XXBDBHelper *dbHelper = [XXBDBHelper shareDBHelper];
    [[dbHelper getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        res = [db tableExists:tableName];
    }];
    return res;
}

/** 获取列名 */
+ (NSArray *)getColumns {
    __block NSArray *columns = nil;
    if (XXBDBHelperIsInHelperQueue) {
        columns = [self p_getColumns];
    } else {
        dispatch_sync(XXBDBHelperQueue, ^{
            columns = [self p_getColumns];
        });
    }
    return columns;
}

/**
 * 创建表
 * 如果已经创建，返回YES
 */
+ (BOOL)createTable {
    
    __block BOOL res = YES;
    if (XXBDBHelperIsInHelperQueue) {
        res = [self p_clearTable];
    } else {
        dispatch_sync(XXBDBHelperQueue, ^{
            res = [self p_clearTable];
        });
    }
    return res;
}

#pragma mark - save

- (BOOL)saveSync {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        XXBDBLogInfo;
        res = [self p_save];
    });
    return res;
}

- (void)saveAsync:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async([[XXBDBHelper shareDBHelper] getBDBHelperQueue], ^{
            XXBDBLogInfo;
            BOOL res = [self p_save];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async([[XXBDBHelper shareDBHelper] getBDBHelperQueue], ^{
            complate([self p_save]);
        });
    }
}

+ (BOOL)saveObjectsSync:(NSArray *)array {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_saveObjects:array];
    });
    return res;
}

+ (void)saveObjectsAsync:(NSArray *)array complate:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async([[XXBDBHelper shareDBHelper] getBDBHelperQueue], ^{
            XXBDBLogInfo;
            BOOL res = [self p_saveObjects:array];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async([[XXBDBHelper shareDBHelper] getBDBHelperQueue], ^{
            BOOL res = [self p_saveObjects:array];
            complate(res);
        });
    }
}

- (BOOL)saveOrUpdateSync {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_saveOrUpdate];
    });
    return res;
}

- (void)saveOrUpdateAsync:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_sync(XXBDBHelperQueue, ^{
            BOOL res = [self p_saveOrUpdate];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        BOOL res = [self p_saveOrUpdate];
        complate(res);
    }
}

- (BOOL)saveOrUpdateSyncByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_saveOrUpdateByColumnName:columnName AndColumnValue:columnValue];
    });
    return res;
}

- (void)saveOrUpdateAsyncByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue complate:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_saveOrUpdateByColumnName:columnName AndColumnValue:columnValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_saveOrUpdateByColumnName:columnName AndColumnValue:columnValue];
            complate(res);
        });
    }
}


#pragma mark - update

- (BOOL)updateSync {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_update];
    });
    return res;
}
- (void)updateAsync:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_update];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_update];
            complate(res);
        });
    }
}


/*
 * 批量更新数据
 */
+ (BOOL)updateSyncObjects:(NSArray *)array {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_updateObjects:array];
    });
    return res;
}

+ (void)updateAsyncObjects:(NSArray *)array complate:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_updateObjects:array];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_updateObjects:array];
            complate(res);
        });
    }
}

- (BOOL)deleteObjectSync {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_deleteObject];
    });
    return res;
}

- (void)deleteObjectAsync:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObject];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObject];
            complate(res);
        });
    }
}

+ (BOOL)deleteSyncObjects:(NSArray *)array {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_deleteObjects:array];
    });
    return res;
}
+ (void)deleteAsyncObjects:(NSArray *)array complate:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjects:array];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjects:array];
            complate(res);
        });
    }
}

+ (BOOL)deleteSyncObjectsByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_deleteObjectsByCriteria:criteria];
    });
    return res;
}

+ (void)deleteAsyncObjectsByCriteria:(NSString *)criteria complate:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjectsByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjectsByCriteria:criteria];
            complate(res);
        });
    }
}

+ (BOOL)deleteSyncObjectsWithFormat:(NSString *)format, ... {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_deleteObjectsByCriteria:criteria];
    });
    return res;
}

+ (void)deleteAsyncObjectsComplate:(XXBDBComplate)complate WithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjectsByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_deleteObjectsByCriteria:criteria];
            complate(res);
        });
    }
}

+ (BOOL)clearTableSync {
    XXBDBHelpJudjeQueueDifferent;
    __block BOOL res = NO;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_clearTable];
    });
    return res;
}
+ (void)clearTableAsync:(XXBDBComplate)complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_clearTable];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
        
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            BOOL res = [self p_clearTable];
            complate(res);
        });
    }
}


#pragma mark - 查找
+ (NSArray *)findAllSync {
    XXBDBHelpJudjeQueueDifferent;
    __block NSArray *modelArray;
    dispatch_sync(XXBDBHelperQueue, ^{
        modelArray = [self p_findAll];
    });
    return modelArray;
}

+ (void)findAllAsync:(void(^)(NSArray *answerArray))complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            __block NSArray *modelArray;
            modelArray = [self p_findAll];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(modelArray);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            __block NSArray *modelArray;
            modelArray = [self p_findAll];
            complate(modelArray);
        });
    }
}

+ (instancetype)findFirstWithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self p_findFirstByCriteria:criteria];
}

+ (instancetype)findSyncByPK:(int)inPk {
    XXBDBHelpJudjeQueueDifferent;
    __block id res;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_findByPK:inPk];
    });
    return res;
}
+ (void)findAsyncByPK:(int)inPk complate:(void (^)(id))complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findByPK:inPk];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findByPK:inPk];
            complate(res);
        });
    }
}

+ (instancetype)findSyncFirstWithFormat:(NSString *)format, ... {
    XXBDBHelpJudjeQueueDifferent;
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    __block id res = nil;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_findByCriteria:criteria];
    });
    return res;
}

+ (void)findAsyncFirstComplate:(void(^)(id answer))complate WithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findByCriteria:criteria];
            complate(res);
        });
    }
}

+ (instancetype)findSyncFirstByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueDifferent;
    __block id res;
    dispatch_sync(XXBDBHelperQueue, ^{
        res = [self p_findFirstByCriteria:criteria];
    });
    return res;
}

+ (void)findAsyncFirstByCriteria:(NSString *)criteria complate:(void(^)(id answer))complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findFirstByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(res);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            id res = [self p_findFirstByCriteria:criteria];
            complate(res);
        });
    }
    
}

+ (NSArray *)findSyncWithFormat:(NSString *)format, ... {
    XXBDBHelpJudjeQueueDifferent;
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    __block NSArray *array;
    dispatch_sync(XXBDBHelperQueue, ^{
        array = [self p_findByCriteria:criteria];
    });
    return array;
    
}

+ (void )findAsyncComplate:(void(^)(NSArray *answerArray))complate WithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            NSArray *resArray = [self p_findByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(resArray);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            NSArray *resArray = [self p_findByCriteria:criteria];
            complate(resArray);
        });
    }
}

+ (NSArray *)findSyncByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueDifferent;
    __block NSArray *resArray;
    dispatch_sync(XXBDBHelperQueue, ^{
        resArray = [self p_findFirstByCriteria:criteria];
    });
    return resArray;
    
}
+ (void)findAsyncByCriteria:(NSString *)criteria complate:(void(^)(NSArray *answerArray))complate {
    if (XXBDBHelperIsInMainThread) {
        dispatch_async(XXBDBHelperQueue, ^{
            NSArray *resArray = [self p_findByCriteria:criteria];
            dispatch_async(dispatch_get_main_queue(), ^{
                complate(resArray);
            });
        });
    } else {
        dispatch_async(XXBDBHelperQueue, ^{
            NSArray *resArray = [self p_findByCriteria:criteria];
            complate(resArray);
        });
    }
}

#pragma mark - util method
+ (NSString *)getColumeAndTypeString {
    NSMutableString* pars = [NSMutableString string];
    NSDictionary *dict = [self.class getAllProperties];
    
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    NSMutableArray *proTypes = [dict objectForKey:@"type"];
    
    for (int i=0; i< proNames.count; i++) {
        [pars appendFormat:@"%@ %@",[proNames objectAtIndex:i],[proTypes objectAtIndex:i]];
        if(i+1 != proNames.count) {
            [pars appendString:@","];
        }
    }
    return pars;
}

#pragma mark - must be override method
/** 如果子类中有一些property不需要创建数据库字段，那么这个方法必须在子类中重写
 */
+ (NSArray *)transients {
    return [NSArray array];
}

#pragma mark - private function

+ (BOOL)p_createTable {
    XXBDBHelpJudjeQueueSame;
    __block BOOL res = YES;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *columeAndType = [self.class getColumeAndTypeString];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@);",tableName,columeAndType];
        if (![db executeUpdate:sql]) {
            res = NO;
            *rollback = YES;
            return;
        };
        
        NSMutableArray *columns = [NSMutableArray array];
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
        NSDictionary *dict = [self.class getAllProperties];
        NSArray *properties = [dict objectForKey:@"name"];
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"NOT (SELF IN %@)",columns];
        //过滤数组
        NSArray *resultArray = [properties filteredArrayUsingPredicate:filterPredicate];
        for (NSString *column in resultArray) {
            NSUInteger index = [properties indexOfObject:column];
            NSString *proType = [[dict objectForKey:@"type"] objectAtIndex:index];
            NSString *fieldSql = [NSString stringWithFormat:@"%@ %@",column,proType];
            NSString *sql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ ",NSStringFromClass(self.class),fieldSql];
            if (![db executeUpdate:sql]) {
                res = NO;
                *rollback = YES;
                return ;
            }
        }
    }];
    
    return res;
}

+ (NSArray *)p_getColumns {
    XXBDBHelpJudjeQueueSame;
    __block NSMutableArray *columns = [NSMutableArray array];
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        FMResultSet *resultSet = [db getTableSchema:tableName];
        while ([resultSet next]) {
            NSString *column = [resultSet stringForColumn:@"name"];
            [columns addObject:column];
        }
    }];
    return [columns copy];
}


- (BOOL)p_save {
    XXBDBHelpJudjeQueueSame;
    NSString *tableName = NSStringFromClass(self.class);
    NSMutableString *keyString = [NSMutableString string];
    NSMutableString *valueString = [NSMutableString string];
    NSMutableArray *insertValues = [NSMutableArray  array];
    for (int i = 0; i < self.columeNames.count; i++) {
        NSString *proname = [self.columeNames objectAtIndex:i];
        if ([proname isEqualToString:primaryId]) {
            continue;
        }
        [keyString appendFormat:@"%@,", proname];
        [valueString appendString:@"?,"];
        id value = [self valueForKey:proname];
        if (!value) {
            value = @"";
        }
        [insertValues addObject:value];
    }
    
    [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
    [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
    
    __block BOOL res = NO;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithDBModel:self] inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
        res = [db executeUpdate:sql withArgumentsInArray:insertValues];
        self.pk = res?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
        XXBDBLogInfoFmort( @"%@",res ? @"插入成功":@"插入失败");
    }];
    return res;
}

/*
 * 批量保存对象
 */
+ (BOOL)p_saveObjects:(NSArray *)array {
    XXBDBHelpJudjeQueueSame;
    //判断是否是JKBaseModel的子类
    for (XXBDBModel *model in array) {
        if (![model isKindOfClass:[XXBDBModel class]]) {
            XXBDBLog(XXBDBLogLevelError, @"数据不合法");
            return NO;
        }
    }
    __block BOOL res = YES;
    
    // 如果要支持事务
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (XXBDBModel *model in array) {
            NSString *tableName = NSStringFromClass(model.class);
            NSMutableString *keyString = [NSMutableString string];
            NSMutableString *valueString = [NSMutableString string];
            NSMutableArray *insertValues = [NSMutableArray  array];
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:primaryId]) {
                    continue;
                }
                [keyString appendFormat:@"%@,", proname];
                [valueString appendString:@"?,"];
                id value = [model valueForKey:proname];
                if (!value) {
                    value = @"";
                }
                [insertValues addObject:value];
            }
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            [valueString deleteCharactersInRange:NSMakeRange(valueString.length - 1, 1)];
            
            NSString *sql = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES (%@);", tableName, keyString, valueString];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:insertValues];
            model.pk = flag?[NSNumber numberWithLongLong:db.lastInsertRowId].intValue:0;
            NSLog(flag?@"插入成功":@"插入失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

- (BOOL)p_saveOrUpdate {
    id primaryValue = [self valueForKey:primaryId];
    if ([primaryValue intValue] <= 0) {
        return [self p_save];
    }
    return [self p_update];
}

- (BOOL)p_saveOrUpdateByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue {
    XXBDBHelpJudjeQueueSame;
    id record = [[self class] p_findFirstByCriteria:[NSString stringWithFormat:@"where %@ = %@",columnName,columnValue]];
    if (record) {
        id primaryValue = [record valueForKey:primaryId]; //取到了主键PK
        if ([primaryValue intValue] <= 0) {
            return [self p_save];
        } else {
            self.pk = [primaryValue integerValue];
            return [self p_update];
        }
    }else{
        return [self p_save];
    }
}

/*
 * 更新单个对象
 */
- (BOOL)p_update {
    XXBDBHelpJudjeQueueSame;
    __block BOOL res = NO;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithDBModel:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        id primaryValue = [self valueForKey:primaryId];
        if (!primaryValue || primaryValue <= 0) {
            return ;
        }
        NSMutableString *keyString = [NSMutableString string];
        NSMutableArray *updateValues = [NSMutableArray  array];
        for (int i = 0; i < self.columeNames.count; i++) {
            NSString *proname = [self.columeNames objectAtIndex:i];
            if ([proname isEqualToString:primaryId]) {
                continue;
            }
            [keyString appendFormat:@" %@=?,", proname];
            id value = [self valueForKey:proname];
            if (!value) {
                value = @"";
            }
            [updateValues addObject:value];
        }
        
        //删除最后那个逗号
        [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@ = ?;", tableName, keyString, primaryId];
        [updateValues addObject:primaryValue];
        res = [db executeUpdate:sql withArgumentsInArray:updateValues];
        XXBDBLogInfoFmort(@"%@",res?@"更新成功":@"更新失败");
    }];
    return res;
}

/** 批量更新用户对象*/
+ (BOOL)p_updateObjects:(NSArray *)array {
    XXBDBHelpJudjeQueueSame;
    for (XXBDBModel *model in array) {
        if (![model isKindOfClass:[XXBDBModel class]]) {
            return NO;
        }
    }
    __block BOOL res = YES;
    // 如果要支持事务
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (XXBDBModel *model in array) {
            NSString *tableName = NSStringFromClass(model.class);
            id primaryValue = [model valueForKey:primaryId];
            if (!primaryValue || primaryValue <= 0) {
                res = NO;
                *rollback = YES;
                return;
            }
            
            NSMutableString *keyString = [NSMutableString string];
            NSMutableArray *updateValues = [NSMutableArray  array];
            for (int i = 0; i < model.columeNames.count; i++) {
                NSString *proname = [model.columeNames objectAtIndex:i];
                if ([proname isEqualToString:primaryId]) {
                    continue;
                }
                [keyString appendFormat:@" %@=?,", proname];
                id value = [model valueForKey:proname];
                if (!value) {
                    value = @"";
                }
                [updateValues addObject:value];
            }
            
            //删除最后那个逗号
            [keyString deleteCharactersInRange:NSMakeRange(keyString.length - 1, 1)];
            NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@=?;", tableName, keyString, primaryId];
            [updateValues addObject:primaryValue];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:updateValues];
            NSLog(flag?@"更新成功":@"更新失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    
    return res;
}

/** 删除单个对象 */
- (BOOL)p_deleteObject {
    XXBDBHelpJudjeQueueSame;
    __block BOOL res = NO;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithDBModel:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        id primaryValue = [self valueForKey:primaryId];
        if (!primaryValue || primaryValue <= 0) {
            return ;
        }
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,primaryId];
        res = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
        XXBDBLogInfoFmort(@"%@",res?@"删除成功":@"删除失败");
    }];
    return res;
}

/** 批量删除用户对象 */
+ (BOOL)p_deleteObjects:(NSArray *)array {
    XXBDBHelpJudjeQueueSame;
    for (XXBDBModel *model in array) {
        if (![model isKindOfClass:[XXBDBModel class]]) {
            return NO;
        }
    }
    
    __block BOOL res = YES;
    // 如果要支持事务
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (XXBDBModel *model in array) {
            NSString *tableName = NSStringFromClass(model.class);
            id primaryValue = [model valueForKey:primaryId];
            if (!primaryValue || primaryValue <= 0) {
                return ;
            }
            
            NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",tableName,primaryId];
            BOOL flag = [db executeUpdate:sql withArgumentsInArray:@[primaryValue]];
            XXBDBLogInfoFmort(@"%@",flag?@"删除成功":@"删除失败");
            if (!flag) {
                res = NO;
                *rollback = YES;
                return;
            }
        }
    }];
    return res;
}

/*
 * 通过条件删除数据
 */
+ (BOOL)p_deleteObjectsByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueSame;
    __block BOOL res = NO;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ %@ ",tableName,criteria];
        res = [db executeUpdate:sql];
        XXBDBLogInfoFmort(@"%@",res?@"删除成功":@"删除失败");
    }];
    return res;
}

/** 通过条件删除 (多参数）--2 */
+ (BOOL)p_deleteObjectsWithFormat:(NSString *)format, ... {
    XXBDBHelpJudjeQueueSame;
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    
    return [self p_deleteObjectsByCriteria:criteria];
}

/** 清空表 */
+ (BOOL)p_clearTable {
    XXBDBHelpJudjeQueueSame;
    __block BOOL res = NO;
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@",tableName];
        res = [db executeUpdate:sql];
        XXBDBLogInfoFmort(@"%@",res?@"清空成功":@"清空失败");
    }];
    return res;
}

/*
 * 查询全部数据
 */
+ (NSArray *)p_findAll {
    XXBDBHelpJudjeQueueSame;
    NSMutableArray *modelArray = [NSMutableArray array];
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@",tableName];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            XXBDBModel *model = [[self.class alloc] init];
            for (int i=0; i< model.columeNames.count; i++) {
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                if ([columeType isEqualToString:SQLTEXT]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else if ([columeType isEqualToString:SQLBLOB]) {
                    [model setValue:[resultSet dataForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            [modelArray addObject:model];
            FMDBRelease(model);
        }
    }];
    return modelArray;
}

+ (instancetype)p_findByPK:(int)inPk {
    XXBDBHelpJudjeQueueSame;
    NSString *condition = [NSString stringWithFormat:@"WHERE %@=%d",primaryId,inPk];
    return [self p_findFirstByCriteria:condition];
}

+ (NSArray *)p_findWithFormat:(NSString *)format, ... {
    va_list ap;
    va_start(ap, format);
    NSString *criteria = [[NSString alloc] initWithFormat:format locale:[NSLocale currentLocale] arguments:ap];
    va_end(ap);
    return [self p_findByCriteria:criteria];
}

/** 查找某条数据 */
+ (instancetype)p_findFirstByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueSame;
    NSArray *results = [self p_findByCriteria:criteria];
    if (results.count < 1) {
        return nil;
    }
    return [results firstObject];
}

/** 通过条件查找数据 */
+ (NSArray *)p_findByCriteria:(NSString *)criteria {
    XXBDBHelpJudjeQueueSame;
    NSMutableArray *users = [NSMutableArray array];
    [[[XXBDBHelper shareDBHelper] getDatabaseQueueWithClass:self] inDatabase:^(FMDatabase *db) {
        NSString *tableName = NSStringFromClass(self.class);
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ %@",tableName,criteria];
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            XXBDBModel *model = [[self.class alloc] init];
            for (int i=0; i< model.columeNames.count; i++) {
                NSString *columeName = [model.columeNames objectAtIndex:i];
                NSString *columeType = [model.columeTypes objectAtIndex:i];
                if ([columeType isEqualToString:SQLTEXT]) {
                    [model setValue:[resultSet stringForColumn:columeName] forKey:columeName];
                } else if ([columeType isEqualToString:SQLBLOB]) {
                    [model setValue:[resultSet dataForColumn:columeName] forKey:columeName];
                } else {
                    [model setValue:[NSNumber numberWithLongLong:[resultSet longLongIntForColumn:columeName]] forKey:columeName];
                }
            }
            [users addObject:model];
            FMDBRelease(model);
        }
    }];
    return users;
}


- (NSString *)description {
    NSString *result = [NSString stringWithFormat:@"< %@ : %p \n",[self class],self];
    NSDictionary *dict = [self.class getAllProperties];
    NSMutableArray *proNames = [dict objectForKey:@"name"];
    for (int i = 0; i < proNames.count; i++) {
        NSString *proName = [proNames objectAtIndex:i];
        id  proValue = [self valueForKey:proName];
        result = [result stringByAppendingFormat:@"%@:%@\n",proName,proValue];
    }
    result = [result stringByAppendingFormat:@">\n"];
    return result;
}
@end
