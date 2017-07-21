//
//  XXBDBModel.h
//  XXBDBModelDemo
//
//  Created by xiaobing on 2017/7/19.
//  Copyright © 2017年 xiaobing. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^XXBDBComplate)(BOOL complate);

/** SQLite五种数据类型 */
#define SQLTEXT     @"TEXT"
#define SQLINTEGER  @"INTEGER"
#define SQLREAL     @"REAL"
#define SQLBLOB     @"BLOB"
#define SQLNULL     @"NULL"
#define PrimaryKey  @"primary key"

#define primaryId   @"pk"

@interface XXBDBModel : NSObject

/*
 * 主键 id
 */
@property (nonatomic, assign) NSInteger                         pk;

/*
 * 列名 
 */
@property (retain, readonly, nonatomic) NSMutableArray          *columeNames;

/*
 * 列类型 
 */
@property (retain, readonly, nonatomic) NSMutableArray          *columeTypes;

/*
 *  如果需要单独设置数据的位置的话需要单独写这个接口
 */
+ (NSString *)getDBPathName;

/**
 *  获取该类的所有属性
 */
+ (NSDictionary *)getPropertys;

/*
 * 获取所有属性，包括主键 
 */
+ (NSDictionary *)getAllProperties;

/*
 * 数据库中是否存在表 
 */
+ (BOOL)isExistInTable;

/** 表中的字段*/
+ (NSArray *)getColumns;

/*
 * 保存单个数据
 */
- (BOOL)saveSync;
- (void)saveAsync:(XXBDBComplate)complate;

/*
 * 批量保存数据
 */
+ (BOOL)saveObjectsSync:(NSArray *)array;
+ (void)saveObjectsAsync:(NSArray *)array complate:(XXBDBComplate)complate;


/** 保存或更新
 * 如果不存在主键，保存，
 * 有主键，则更新
 */

- (BOOL)saveOrUpdateSync;
- (void)saveOrUpdateAsync:(XXBDBComplate)complate;

/** 保存或更新
 * 如果根据特定的列数据可以获取记录，则更新，
 * 没有记录，则保存
 */
- (BOOL)saveOrUpdateSyncByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue;
- (void)saveOrUpdateAsyncByColumnName:(NSString*)columnName AndColumnValue:(NSString*)columnValue complate:(XXBDBComplate)complate;

/*
 * 更新单个数据
 */
- (BOOL)updateSync;
- (void)updateAsync:(XXBDBComplate)complate;

/*
 * 批量更新数据
 */
+ (BOOL)updateSyncObjects:(NSArray *)array;
+ (void)updateAsyncObjects:(NSArray *)array complate:(XXBDBComplate)complate;

/*
 * 删除单个数据 
 */
- (BOOL)deleteObjectSync;
- (void)deleteObjectAsync:(XXBDBComplate)complate;


/*
 * 批量删除数据 
 */
+ (BOOL)deleteSyncObjects:(NSArray *)array;
+ (void)deleteAsyncObjects:(NSArray *)array complate:(XXBDBComplate)complate;

/*
 * 通过条件删除数据 
 */
+ (BOOL)deleteSyncObjectsByCriteria:(NSString *)criteria;
+ (void)deleteAsyncObjectsByCriteria:(NSString *)criteria complate:(XXBDBComplate)complate;

/*
 * 通过条件删除 (多参数）--2 
 */
+ (BOOL)deleteSyncObjectsWithFormat:(NSString *)format, ...;
+ (void)deleteAsyncObjectsComplate:(XXBDBComplate)complate WithFormat:(NSString *)format, ...;

/*
 * 清空表 
 */
+ (BOOL)clearTableSync;
+ (void)clearTableAsync:(XXBDBComplate)complate;

/*
 * 查询全部数据 
 */

+ (NSArray *)findAllSync;
+ (void)findAllAsync:(void(^)(NSArray *answerArray))complate;

/*
 * 通过主键查询 
 */
+ (instancetype)findSyncByPK:(int)inPk;
+ (void)findAsyncByPK:(int)inPk complate:(void(^)(id answer))complate;

+ (instancetype)findSyncFirstWithFormat:(NSString *)format, ...;
+ (void)findAsyncFirstComplate:(void(^)(id answer))complate WithFormat:(NSString *)format, ...;

/*
 * 查找某条数据
 */
+ (instancetype)findSyncFirstByCriteria:(NSString *)criteria;
+ (void)findAsyncFirstByCriteria:(NSString *)criteria complate:(void(^)(id answer))complate;

+ (NSArray *)findSyncWithFormat:(NSString *)format, ...;
+ (void)findAsyncComplate:(void(^)(NSArray *answerArray))complate WithFormat:(NSString *)format, ...;

/** 通过条件查找数据
 * 这样可以进行分页查询 @" WHERE pk > 5 limit 10"
 */
+ (NSArray *)findSyncByCriteria:(NSString *)criteria;
+ (void)findAsyncByCriteria:(NSString *)criteria complate:(void(^)(NSArray *answerArray))complate;

/**
 * 创建表
 * 如果已经创建，返回YES
 */
+ (BOOL)createTable;

#pragma mark - must be override method

/*
 * 如果子类中有一些property不需要创建数据库字段，那么这个方法必须在子类中重写
 */
+ (NSArray *)transients;
@end
