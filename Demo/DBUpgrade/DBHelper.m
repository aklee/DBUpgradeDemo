//
//  DBUpgrade.m
//  Demo
//
//  Created by ak on 2018/3/14.
//

#import "DBHelper.h"
#define kDBVersionKey @"DBVersion"
@interface DBHelper()
@property(nonatomic,strong)FMDatabaseQueue *queue;
@end
@implementation DBHelper

static DBHelper *helper;
+(instancetype)sharedHelper{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [DBHelper new];
    });
    return helper;
}

-(instancetype)init{
    self = [super init];
    NSString*docPath=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dbPath=[docPath stringByAppendingPathComponent:@"App.db"];
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    self.queue = queue;
    return self;
}


+(NSInteger)currentVersion{
    return 2;
}

+ (BOOL)checkTableExist:(NSString *)tableName Database:(FMDatabase *)db {
    BOOL isExists = NO;
    
    if(tableName && db) {
        NSString *sql = @"SELECT COUNT(*) FROM sqlite_master where type='table' and name=?";
        NSArray *parameters = [NSArray arrayWithObjects:tableName, nil];
        
        FMResultSet *set = [db executeQuery:sql withArgumentsInArray:parameters];
        while ([set next]) {
            isExists = [set intForColumnIndex:0] > 0;
        }
        
        [set close];
    }
    
    return isExists;
}

+ (bool)addColumn:(NSString *)columnName dataType:(NSString *)dataType default:(NSString *)value inTable:(NSString *)tableName Database:(FMDatabase *)db {
    BOOL isExists = NO,result=NO;
    if(columnName && tableName && db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM %@ limit 0", tableName];
        FMResultSet *set = [db executeQuery:sql];
        if (set) {
            isExists = [set columnIndexForName:columnName] >= 0;
        }
        [set close];
        
        if(!isExists) {
            NSString *alterSQL;
            if(value) {
                alterSQL = [NSString stringWithFormat:@"alter table %@ add %@ %@ default %@", tableName, columnName, dataType, value];
            }
            else {
                alterSQL = [NSString stringWithFormat:@"alter table %@ add %@ %@", tableName, columnName, dataType];
            }
            result = [db executeUpdate:alterSQL];
        }
    }
    return result;
}


-(NSInteger)dbVersion:(FMDatabase *)db{
    NSInteger ver = 0;
    FMResultSet *set = [db executeQuery:[NSString stringWithFormat:@"select Value from Config where Key = '%@' ",kDBVersionKey]];
    if ([set next]) {
        NSString*key = [set stringForColumn:@"Value"];
        ver = [key integerValue];
        [set close];
    }
    return ver;
    
}

-(void)inDatabase:(void(^)(FMDatabase *db))block{
    if (!block) {
        return;
    }
    [self.queue inDatabase:^(FMDatabase * _Nonnull db) {
        block(db);
    }];
}

-(bool)upgrade{
     NSArray *arr = @[[DBVersion1 new],[DBVersion2 new]];
    __block bool result = NO;
    [self.queue inDatabase:^(FMDatabase * _Nonnull db) {
        if (![DBHelper checkTableExist:@"Config" Database:db]){
            id<DBUpgradeDelegate> currentVersion = arr[0];
            if(![currentVersion install:db]){
                NSLog(@"首次初始化db失败");
            }
        }
        
        if([DBHelper checkTableExist:@"Config" Database:db]){
            NSInteger dbVer=[self dbVersion:db];
            if(dbVer==0){
                //db读取失败
                result=NO;
                NSLog(@"db读取失败");
                return ;
            }
            while ([DBHelper currentVersion]>dbVer) {//2>1
                id<DBUpgradeDelegate> currentVersion = arr[dbVer];
                if([currentVersion upgrade:db]){
                    dbVer++;
                }else{
                    NSLog(@"数据库版本%@升级失败",@(dbVer));
                    result=NO;
                    return ;
                }
            }
        }
    }];
   return result;
}
@end


@implementation DBVersion1
-(bool)install:(FMDatabase *)db{
    if (!db) {
        return NO;
    }
    __block bool result = YES;
    [db beginTransaction];
    //首次初始化所有表结构
    NSString *sql = @"\
    CREATE TABLE IF NOT EXISTS Config (Key TEXT PRIMARY KEY, Value TEXT);\
    CREATE TABLE  UserInfo (\
    IDs blob PRIMARY KEY,\
    Type integer,\
    CreateTime integer,\
    Status integer,\
    UserName text );\
    \
    CREATE TABLE  UserInfo2 (\
    IDs blob PRIMARY KEY,\
    Type integer,\
    CreateTime integer,\
    Status integer,\
    UserName text );\
    \
    CREATE TABLE UserInfo3(\
    IDs blob PRIMARY KEY,\
    Type integer,\
    CreateTime integer,\
    Status integer,\
    UserName text );\
    ";
    sql=[sql stringByTrimmingCharactersInSet:[NSCharacterSet
                                              whitespaceCharacterSet]];
    NSArray*sqls=[sql componentsSeparatedByString:@";"];
    [sqls enumerateObjectsUsingBlock:^(NSString *   s, NSUInteger idx, BOOL * _Nonnull stop) {
        if (s.length>0) {
            bool r=[db executeUpdate:s];
            if (!r) {
                result=r;
                *stop=YES;
            }
        }
    }];
    if (!result) {
        [db rollback];
        return NO;
    }
    
    
    [db executeUpdate:@"INSERT OR REPLACE INTO  Config (Key,Value) VALUES(?,?)",kDBVersionKey,@"1"];
    if (!result) {
        [db rollback];
        return NO;
    }
    [db commit];
    
    return YES;
}
@end


@implementation DBVersion2
//-(bool)install:(FMDatabase *)db{
//    
//    bool result = NO;
//    [db beginTransaction];
//    NSString *sql = @"\
//    CREATE TABLE IF NOT EXISTS V2Table (\
//    IDs blob PRIMARY KEY,\
//    Type integer,\
//    CreateTime integer,\
//    Status integer,\
//    UserName text );\
//    ";
//    
//    result=[db executeUpdate:sql];
//    if (!result) {
//        [db rollback];
//        return NO;
//    }
//    
//    [db executeUpdate:@"INSERT OR REPLACE INTO  Config (Key,Value) VALUES(?,?)",kDBVersionKey,@"2"];
//    if (!result) {
//        [db rollback];
//        return NO;
//    }
//    [db commit];
//    return YES;
//}
-(bool)upgrade:(FMDatabase *)db{
    if (!db) {
        return NO;
    }
    [db beginTransaction];
    bool result = NO;
    result=[db executeUpdate:@"INSERT OR REPLACE INTO  Config (Key,Value) VALUES(?,?)",kDBVersionKey,@"2"];
    if (!result) {
        [db rollback];
        return NO;
    }
    
    result=[DBHelper addColumn:@"V2_NickName" dataType:@"text" default:@"'ak'" inTable:@"UserInfo" Database:db];
    if (!result) {
        [db rollback];
        return NO;
    }
    result=[DBHelper addColumn:@"V2_Age" dataType:@"integer" default:@"18" inTable:@"UserInfo" Database:db];
    if (!result) {
        [db rollback];
        return NO;
    }
    [db commit];
    return YES;
}
@end

