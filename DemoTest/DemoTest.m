//
//  DemoTest.m
//  DemoTest
//
//  Created by ak on 2018/3/16.
//
#import <XCTest/XCTest.h>
#import "DBHelper.h"
#import "OCMock.h"
#define kDBVersionKey @"DBVersion"
@interface DemoTest : XCTestCase

@end

@implementation DemoTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}
-(void)removeFile{
    NSError*err;
    NSString*docPath=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *dbPath=[docPath stringByAppendingPathComponent:@"App.db"];
    NSLog(@"%@",dbPath);
    bool r = [[NSFileManager defaultManager] removeItemAtPath:dbPath error:&err];
    if (!r) {
        NSLog(@"删除db文件失败 %@",err);
    }
}

-(void)setCurrentVersion:(int)v{
    OCMockObject * mock = [OCMockObject mockForClass:[DBHelper class]];
    [[[mock stub] andReturnValue:@(v)] currentVersion];
    NSInteger ver = [DBHelper currentVersion];
    NSLog(@"最新版本 %@",@(ver));
}
-(void)checkDBVersion:(int)v{
    [[DBHelper sharedHelper] inDatabase:^(FMDatabase *db) {
        NSInteger ver = 0;
        FMResultSet *set = [db executeQuery:[NSString stringWithFormat:@"select Value from Config where Key = '%@' ",kDBVersionKey]];
        if ([set next]) {
            NSString*key = [set stringForColumn:@"Value"];
            ver = [key integerValue];
            [set close];
            XCTAssert(ver==v,@"db版本错误");
        }
    }];
}
- (void)testV1 {//首次安装
    [self removeFile];
    [self setCurrentVersion:1];
    [[DBHelper sharedHelper] upgrade];
    
    [self checkDBVersion:1];
    
}


-(void)testV1_V2 {//首次安装，V1升级到V2
    [self removeFile];
    [self setCurrentVersion:2];
    [[DBHelper sharedHelper] upgrade];
    [self checkDBVersion:2];
}

-(void)testV2{
    //升级V2失败。重试成功
    [self removeFile];
    [self setCurrentVersion:2];  
    OCMockObject *mock = [OCMockObject mockForClass:[DBHelper class]];
    [[[mock stub] andReturnValue:@NO]  addColumn:[OCMArg any] dataType:[OCMArg any] default:[OCMArg any] inTable:[OCMArg any] Database:[OCMArg any]];
    
    [[DBHelper sharedHelper] upgrade];
    
    [self checkDBVersion:1];//rollback to v1
    
    [mock stopMocking];
    
    [[DBHelper sharedHelper] upgrade];//upgrade to v2
    
    [self checkDBVersion:2];
    
    
}
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
