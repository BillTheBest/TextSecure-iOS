//
//  TSEncryptedDatabase.m
//  TextSecureiOS
//
//  Created by Alban Diquet on 12/29/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "TSEncryptedDatabase.h"
#import "FMDatabaseQueue.h"
#import "FMDatabase.h"
#import "TSStorageError.h"
#import "TSStorageMasterKey.h"


@interface TSEncryptedDatabase(Private)

-(instancetype) initWithDatabaseQueue:(FMDatabaseQueue *)queue;

@end



@implementation TSEncryptedDatabase {
}


+(instancetype) databaseCreateAtFilePath:(NSString *)dbFilePath updateBoolPreference:(NSString *)preferenceName withPassword:(NSData*)dbMasterKey error:(NSError **)error {
    // Sanity check 
    if (!dbMasterKey) {
        return nil;
    }
    // Have we created a DB on this device already ?
    if ([[NSUserDefaults standardUserDefaults] boolForKey:preferenceName]) {
        if (error) {
            *error = [TSStorageError errorDatabaseAlreadyCreated];
        }
        return nil;
    }
    
    // Cleanup remnants of a previous DB
    [TSEncryptedDatabase databaseEraseAtFilePath:dbFilePath updateBoolPreference:preferenceName];
    
    
    // Create the DB
    __block BOOL dbInitSuccess = NO;
    FMDatabaseQueue *dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbFilePath];
    [dbQueue inDatabase:^(FMDatabase *db) {
        if(![db setKeyWithData:dbMasterKey]) {
            return;
        }
        
        FMResultSet *rset = [db executeQuery:@"SELECT count(*) FROM sqlite_master"];
        if (rset) {
            [rset close];
            dbInitSuccess = YES;
            return;
        }
    }];
    
    if (!dbInitSuccess) {
        if (error) {
            *error = [TSStorageError errorDatabaseCreationFailed];
        }
        // Cleanup
        [TSEncryptedDatabase databaseEraseAtFilePath:dbFilePath updateBoolPreference:preferenceName];
        return nil;
    }
    
    TSEncryptedDatabase *encryptedDB = [[TSEncryptedDatabase alloc] initWithDatabaseQueue:dbQueue];
    
    // Success - store in the preferences that the DB has been successfully created
    [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:preferenceName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return encryptedDB;
}


+(instancetype) databaseCreateAtFilePath:(NSString *)dbFilePath updateBoolPreference:(NSString *)preferenceName error:(NSError **)error {
    // Retrieve storage master key
    NSData *dbMasterKey = [TSStorageMasterKey getStorageMasterKeyWithError:error];
    if (!dbMasterKey) {
        return nil;
    }
    return [TSEncryptedDatabase databaseCreateAtFilePath:dbFilePath updateBoolPreference:preferenceName error:error];
    
 
}





+(instancetype) databaseOpenAndDecryptAtFilePath:(NSString *)dbFilePath error:(NSError **)error {    
    // Get the storage master key
    NSData *storageKey = [TSStorageMasterKey getStorageMasterKeyWithError:error];
    if (!storageKey) {
        return nil;
    }
    return [TSEncryptedDatabase databaseOpenAndDecryptAtFilePath:dbFilePath withPassword:storageKey error:error];
}


+(instancetype) databaseOpenAndDecryptAtFilePath:(NSString *)dbFilePath withPassword:(NSData*)storageKey error:(NSError **)error {
    if (!storageKey) {
        return nil;
    }
    // Try to open the DB
    __block BOOL initSuccess = NO;
    FMDatabaseQueue *dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbFilePath];
    
    [dbQueue inDatabase:^(FMDatabase *db) {
        if(![db setKeyWithData:storageKey]) {
            // Supplied password was valid but the master key wasn't
            return;
        }
        // Do a test query to make sure the DB is available
        // if this throws an error, the key was incorrect. If it succeeds and returns a numeric value, the key is correct;
        FMResultSet *rset = [db executeQuery:@"SELECT count(*) FROM sqlite_master"];
        if (rset) {
            [rset close];
            initSuccess = YES;
            return;
        }}];
    
    if (!initSuccess) {
        if (error) {
            *error = [TSStorageError errorStorageKeyCorrupted];
        }
        return nil;
    }
    
    TSEncryptedDatabase *encryptedDB = [[TSEncryptedDatabase alloc] initWithDatabaseQueue:dbQueue];
    return encryptedDB;
}

+(void) databaseEraseAtFilePath:(NSString *)dbFilePath updateBoolPreference:(NSString *)preferenceName {
    // Update the preferences
    [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:preferenceName];
    [[NSUserDefaults standardUserDefaults] synchronize];
    // Erase the DB file
    [[NSFileManager defaultManager] removeItemAtPath:dbFilePath error:nil];
}


-(instancetype) initWithDatabaseQueue:(FMDatabaseQueue *)queue {
    if(self=[super init]) {
        self.dbQueue = queue;
    }
    return self;
}


@end
