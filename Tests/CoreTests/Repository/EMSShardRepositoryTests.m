//
//  Copyright (c) 2017 Emarsys. All rights reserved.
//

#import "Kiwi.h"
#import "EMSSQLiteHelper.h"
#import "EMSSqliteQueueSchemaHandler.h"
#import "EMSShardRepositoryProtocol.h"
#import "EMSShardRepository.h"
#import "EMSShard.h"
#import "EMSTimestampProvider.h"
#import "EMSUUIDProvider.h"
#import "EMSShardQueryAllSpecification.h"
#import "EMSShardDeleteByIdsSpecification.h"
#import "EMSShardQueryByTypeSpecification.h"

#define TEST_DB_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"TestDB.db"]

SPEC_BEGIN(EMSShardRepositoryTests)

        __block EMSSQLiteHelper *helper;
        __block id <EMSShardRepositoryProtocol> repository;

        beforeEach(^{
            [[NSFileManager defaultManager] removeItemAtPath:TEST_DB_PATH
                                                       error:nil];
            helper = [[EMSSQLiteHelper alloc] initWithDatabasePath:TEST_DB_PATH
                                                    schemaDelegate:[EMSSqliteQueueSchemaHandler new]];
            [helper open];
            repository = [[EMSShardRepository alloc] initWithDbHelper:helper];
        });

        afterEach(^{
            [helper close];
        });

        EMSShard *(^createShardWithType)(NSString *type) = ^EMSShard *(NSString *type) {
            return [[EMSShard alloc] initWithShardId:[[[EMSUUIDProvider new] provideUUID] UUIDString]
                                                type:type
                                                data:@{@"key1": @"value1",
                                                    @"key2": @{@"innerKey1": @"innerValue1"}}
                                           timestamp:[[EMSTimestampProvider new] provideTimestamp]
                                                 ttl:42.42];
        };

        EMSShard *(^createShard)() = ^EMSShard *() {
            return createShardWithType(@"shardType");
        };

        describe(@"query", ^{
            it(@"should return empty array when the table is empty", ^{
                NSArray<EMSShard *> *result = [repository query:[EMSShardQueryAllSpecification new]];
                [[result should] beEmpty];
            });
        });

        describe(@"add", ^{
            it(@"should not accept nil", ^{
                @try {
                    [repository add:nil];
                    fail(@"Expected Exception when model is nil!");
                } @catch (NSException *exception) {
                    [[theValue(exception) shouldNot] beNil];
                }
            });

            it(@"should insert the shard into the repository", ^{
                EMSShard *expectedModel = createShard();
                [repository add:expectedModel];
                NSArray<EMSShard *> *result = [repository query:[EMSShardQueryAllSpecification new]];
                [[result.firstObject should] equal:expectedModel];
            });
        });

        describe(@"delete", ^{
            it(@"should delete the model from the table", ^{
                EMSShard *expectedModel = createShard();
                [repository add:expectedModel];
                [repository remove:[[EMSShardDeleteByIdsSpecification alloc] initWithShards:@[expectedModel]]];
                NSArray<EMSShard *> *result = [repository query:[EMSShardQueryAllSpecification new]];
                [[result should] beEmpty];
            });
        });

        describe(@"isEmpty", ^{
            it(@"should return YES when there is no shard in the table", ^{
                [[theValue([repository isEmpty]) should] beYes];
            });

            it(@"should return NO when there are shards in the table", ^{
                EMSShard *expectedModel = createShard();
                [repository add:expectedModel];

                [[theValue([repository isEmpty]) should] beNo];
            });
        });

        describe(@"EMSShardDeleteByIdsSpecification", ^{

            it(@"should delete the correct shard", ^{
                EMSShard *firstModel = createShard();
                EMSShard *secondModel = createShard();
                EMSShard *thirdModel = createShard();
                EMSShard *fourthModel = createShard();

                [repository add:firstModel];
                [repository add:secondModel];
                [repository add:thirdModel];
                [repository add:fourthModel];

                [repository remove:[[EMSShardDeleteByIdsSpecification alloc] initWithShards:@[secondModel, thirdModel]]];

                NSArray *results = [repository query:[EMSShardQueryAllSpecification new]];
                [[theValue([results count]) should] equal:theValue(2)];
                [[results[0] should] equal:firstModel];
                [[results[1] should] equal:fourthModel];
            });
        });

        describe(@"EMSShardQueryAllSpecification", ^{
            it(@"should return with all of the shards", ^{
                EMSShard *firstModel = createShard();
                EMSShard *secondModel = createShard();
                EMSShard *thirdModel = createShard();
                EMSShard *fourthModel = createShard();

                [repository add:firstModel];
                [repository add:secondModel];
                [repository add:thirdModel];
                [repository add:fourthModel];

                NSArray<EMSShard *> *results = [repository query:[EMSShardQueryAllSpecification new]];

                [[theValue([results count]) should] equal:theValue(4)];
                [[results[0] should] equal:firstModel];
                [[results[1] should] equal:secondModel];
                [[results[2] should] equal:thirdModel];
                [[results[3] should] equal:fourthModel];
            });
        });

        describe(@"EMSShardQueryByTypeSpecification", ^{

            it(@"should select all of the shard with the given type", ^{
                EMSShard *firstModel = createShardWithType(@"shardType1");
                EMSShard *secondModel = createShardWithType(@"shardType2");
                EMSShard *thirdModel = createShardWithType(@"shardType2");
                EMSShard *fourthModel = createShardWithType(@"shardType1");

                [repository add:firstModel];
                [repository add:secondModel];
                [repository add:thirdModel];
                [repository add:fourthModel];

                NSArray *results = [repository query:[[EMSShardQueryByTypeSpecification alloc] initWithType:@"shardType1"]];

                [[theValue([results count]) should] equal:theValue(2)];
                [[results[0] should] equal:firstModel];
                [[results[1] should] equal:fourthModel];
            });
        });
SPEC_END