//
//  DBUpgrade.h
//  Demo
//
//  Created by ak on 2018/3/14.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

@interface DBHelper:NSObject
+(instancetype)sharedHelper;
+(NSInteger)currentVersion;
+ (BOOL)checkTableExist:(NSString *)tableName Database:(FMDatabase *)db;
+ (BOOL)addColumn:(NSString *)columnName dataType:(NSString *)dataType default:(NSString *)value inTable:(NSString *)tableName Database:(FMDatabase *)db;

-(NSInteger)dbVersion:(FMDatabase *)db;
-(void)inDatabase:(void(^)(FMDatabase *db))block;
-(bool)upgrade;
@end
@protocol DBUpgradeDelegate<NSObject>
@optional
-(bool)install:(FMDatabase *)db;
-(bool)upgrade:(FMDatabase *)db;
@end


@interface DBVersion1 : NSObject<DBUpgradeDelegate>
@end

@interface DBVersion2 : NSObject<DBUpgradeDelegate>
@end

@interface DBVersion3 : NSObject<DBUpgradeDelegate>
@end



