//
//  TSMessagesDatabase.m
//  TSMessagesDatabase Tests
//
//  Created by Alban Diquet on 11/24/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "TSMessagesDatabase.h"
#import "TSStorageError.h"
#import "Cryptography.h"
#import "NSData+Base64.h"
#import "TSStorageMasterKey.h"
#import "TSThread.h"
#import "TSContact.h"
#import "TSECKeyPair.h"
#import "TSMessage.h"

static NSString *masterPw = @"1234test";



@interface TSECKeyPair (Test)
-(NSData*) getPrivateKey;
@end


@implementation TSECKeyPair (Test)
-(NSData*) getPrivateKey {
    return [NSData dataWithBytes:self->privateKey length:32];
}
@end


@interface TSMessagesDatabaseTests : XCTestCase
@property (nonatomic,strong) TSThread* thread;
@property (nonatomic,strong) TSMessage* message;

@end

@implementation TSMessagesDatabaseTests

- (void)setUp
{
    [super setUp];
    
    self.thread = [TSThread threadWithContacts:@[[[TSContact alloc] initWithRegisteredID:@"678910"]]];
    
    self.message = [TSMessage messageWithContent:@"hey" sender:@"12345" recipient:@"678910" date:[NSDate date]];
    // Remove any existing DB
    [TSMessagesDatabase databaseErase];
    
    
    [TSStorageMasterKey eraseStorageMasterKey];
    [TSStorageMasterKey createStorageMasterKeyWithPassword:masterPw error:nil];
    
    NSError *error;
    
    // tests datbase creation
    
    XCTAssertTrue([TSMessagesDatabase databaseCreateWithError:&error], @"message db creation failed");
    XCTAssertNil(error, @"message db creation returned an error");
    
    // tests is empty
    NSArray* threadsFromDb = [TSMessagesDatabase getThreads];
    NSArray *messages = [TSMessagesDatabase getMessagesOnThread:self.thread];
    XCTAssertTrue([threadsFromDb count]==0, @"there are threads in an empty db");
    XCTAssertTrue([messages count]==0, @"there are threads in an empty db");
    
    [TSMessagesDatabase storeMessage:self.message fromThread:self.thread];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
    [TSStorageMasterKey eraseStorageMasterKey];
}


-(void) testStoreMessage {
    NSArray *messages = [TSMessagesDatabase getMessagesOnThread:self.thread];
    XCTAssertTrue([messages count]==1, @"database should just have one message in it, instead has %d",[messages count]);
    XCTAssertTrue([[[messages objectAtIndex:0] content] isEqualToString:self.message.content], @"message bodies not equal");
    
}
-(void) testStoreThreadCreation {
    NSArray* threadsFromDb = [TSMessagesDatabase getThreads];
    XCTAssertTrue([threadsFromDb count]==1, @"database should just have one thread in it, instead has %d",[threadsFromDb count]);
    
    XCTAssertTrue([[[threadsFromDb objectAtIndex:0] threadID] isEqualToString:self.thread.threadID], @"thread id %@ of thread retreived and my thread %@ not equal", [[threadsFromDb objectAtIndex:0] threadID], self.thread.threadID);
}


/*
 +(NSData*) getAPSDataField:(NSString*)name onThread:(TSThread*)thread;
 +(NSNumber*) getAPSIntField:(NSString*)name onThread:(TSThread*)thread;
 +(BOOL) getAPSBoolField:(NSString*)name onThread:(TSThread*)thread;
 +(NSString*) getAPSStringField:(NSString*)name  onThread:(TSThread*)thread;
 +(NSString*) getAPSFieldName:(NSString*)name onChain:(TSChainType) chain;
 */
-(void)testAPSDataStorage {
    NSData *data = [Cryptography generateRandomBytes:100];
    [TSMessagesDatabase setAPSDataField:@{@"valueField":data,@"threadID":self.thread.threadID, @"nameField": @"cks"}];
    XCTAssertTrue([[TSMessagesDatabase getAPSDataField:@"cks" onThread:self.thread] isEqualToData:data], @"data field retreived  %@ not equal to the randomly generated data and set into the database ",[TSMessagesDatabase getAPSDataField:@"cks" onThread:self.thread]);
}

-(void) testRKStorage {
    NSData* RK = [Cryptography generateRandomBytes:20];
    [TSMessagesDatabase setRK:RK onThread:self.thread];
}

-(void) testCKStorage {
    NSData* CKSending = [Cryptography generateRandomBytes:20];
    NSData* CKReceiving = [Cryptography generateRandomBytes:20];
    [TSMessagesDatabase setCK:CKSending onThread:self.thread onChain:TSReceivingChain];
    [TSMessagesDatabase setCK:CKReceiving onThread:self.thread onChain:TSSendingChain];
    XCTAssertTrue([CKSending isEqualToData:[TSMessagesDatabase getCK:self.thread onChain:TSSendingChain]], @"CK sending on thread %@ getter not equal to setter %@",[TSMessagesDatabase getCK:self.thread onChain:TSSendingChain],CKSending);
    XCTAssertTrue([CKReceiving isEqualToData:[TSMessagesDatabase getCK:self.thread onChain:TSReceivingChain]], @"CK receiving on thread %@ getter not equal to setter %@",[TSMessagesDatabase getCK:self.thread onChain:TSReceivingChain],CKReceiving);
}

-(void) testEphemeralStorageReceiving {
    
    NSData* publicReceiving = [Cryptography generateRandomBytes:32];
    [TSMessagesDatabase setEphemeralOfReceivingChain:publicReceiving onThread:self.thread];
    XCTAssertTrue([publicReceiving isEqualToData:[TSMessagesDatabase getEphemeralOfReceivingChain:self.thread]], @"public receiving ephemeral on thread %@ getter not equal to setter %@",[TSMessagesDatabase getEphemeralOfReceivingChain:self.thread],publicReceiving);
    
}

-(void) testEphemeralStorageSending {
    
    
    TSECKeyPair *pairSending = [TSECKeyPair keyPairGenerateWithPreKeyId:0];
    [TSMessagesDatabase setEphemeralOfSendingChain:pairSending onThread:self.thread];
    TSECKeyPair* pairRetreived = [TSMessagesDatabase getEphemeralOfSendingChain:self.thread];
    XCTAssertTrue([[pairRetreived getPublicKey] isEqualToData:[pairRetreived getPublicKey]], @"public keys of ephemerals on sending chain not equal");
    XCTAssertTrue([[pairRetreived getPrivateKey] isEqualToData:[pairRetreived getPrivateKey]], @"private keys of ephemerals on sending chain not equal");
}

-(void) testEphemeralStorageN {
    
    
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSSendingChain] isEqualToNumber:[NSNumber numberWithInt:0] ],@"N doesn't default to 0");
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSReceivingChain] isEqualToNumber:[NSNumber numberWithInt:0] ],@"N doesn't default to 0 on receiving chain");
    
    XCTAssert([[TSMessagesDatabase getPNs:self.thread] isEqualToNumber:[NSNumber numberWithInt:0] ],@"PNs doesn't default to 0 ");
    
    
    NSNumber* NSending = [NSNumber numberWithInt:2];
    NSNumber* NReceiving = [NSNumber numberWithInt:3];
    NSNumber* PNSending = [NSNumber numberWithInt:5];
    
    [TSMessagesDatabase setN:NSending onThread:self.thread onChain:TSSendingChain];
    [TSMessagesDatabase setN:NReceiving onThread:self.thread onChain:TSReceivingChain];
    [TSMessagesDatabase setPNs:PNSending onThread:self.thread];
    
    
    
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSSendingChain] isEqualToNumber:[NSNumber numberWithInt:2] ],@"N set incorrectly on sending chain");
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSReceivingChain] isEqualToNumber:[NSNumber numberWithInt:3] ],@"N set incorrectly on recieving chain");
    
    
    XCTAssert([[TSMessagesDatabase getPNs:self.thread] isEqualToNumber:[NSNumber numberWithInt:5] ],@"PNs set incorrectly on sending chain ");
    
    XCTAssertTrue([[TSMessagesDatabase getNPlusPlus:self.thread onChain:TSSendingChain] isEqualToNumber:[NSNumber numberWithInt:2]], @"get Nplusplus on sending chain returns wrong thing");
    
    XCTAssertTrue([[TSMessagesDatabase getNPlusPlus:self.thread onChain:TSReceivingChain] isEqualToNumber:[NSNumber numberWithInt:33]], @"get Nplusplus on receiving chain returns wrong thing");
    
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSSendingChain] isEqualToNumber:[NSNumber numberWithInt:3] ],@"N set incorrectly on sending chain via Nplusplus");
    XCTAssert([[TSMessagesDatabase getN:self.thread onChain:TSReceivingChain] isEqualToNumber:[NSNumber numberWithInt:4] ],@"N set incorrectly on recieving chain via Nplusplus");
    
}

@end
