//
//  FileController.m
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "FileController.h"
#import "NSData+Gunzip.h"
#include <zlib.h>
#include "secblock.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "ChatUtils.h"
#import "EncryptionController.h"
#import "NSData+Gunzip.h"
#import "NSString+Sensitivize.h"

using CryptoPP::SecByteBlock;


NSString * const STATE_DIR = @"state";
NSString * const HOME_FILENAME = @"home";
NSString * const STATE_EXTENSION = @"sss";
NSString * const CHAT_DATA_PREFIX = @"chatdata-";
NSString * const PUBLIC_KEYS_DIR = @"publickeys";
NSString * const IDENTITIES_DIR = @"identities";
NSString * const BG_IMAGES_DIR = @"bgimages";
NSString * const UPLOADS_DIR = @"uploads";

NSString * const PUBLIC_KEYS_EXTENSION = @"spk";
NSString * const IDENTITY_EXTENSION = @"ssi";

NSString * const SECRETS_FILENAME = @"secrets";
NSString * const LATEST_VERSIONS_FILENAME = @"latestversions";
NSString * const BACKGROUND_IMAGE_FILENAME = @"bgImage";
NSString * const COOKIE_FILENAME = @"cookie";

NSString * const SECRET_EXTENSION = @"sse";
NSString * const LATEST_VERSIONS_EXTENSION = @"ssv";
NSString * const SECRETS_DIR = @"secrets";
NSString * const LATEST_VERSIONS_DIR = @"latestVersions";

NSInteger const GZIP_MAGIC_1 = 0x1f;
NSInteger const GZIP_MAGIC_2 = 0x8b;

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@implementation FileController


+ (NSString*) getAppSupportDir {
    NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't an App Support Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
        else {
            // *** OPTIONAL *** Mark the directory as excluded from iCloud backups
            NSURL *url = [NSURL fileURLWithPath:appSupportDir];
            if (![url setResourceValue:[NSNumber numberWithBool:YES]
                                forKey:NSURLIsExcludedFromBackupKey
                                 error:&error])
            {
                DDLogVerbose(@"Error excluding %@ from backup %@", [url lastPathComponent], error.localizedDescription);
            }
            else {
                DDLogVerbose(@"Yay");
            }
        }
    }
    
    return appSupportDir;
}

+ (NSString*) getDocumentsDir {
    NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't a Documents Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:documentsDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
    }
    
    return documentsDir;
}

+ (NSString*) getCacheDir {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't an App Support Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
    }
    
    return cacheDir;
}

+(NSString *) getHomeFilename {
    return [self getFilename:HOME_FILENAME];
}

+(NSString *) getBackgroundImageFilename {
    NSString * dir = [self getBgImagesDirectoryForUser:[[IdentityController sharedInstance] getLoggedInUser]];
    return [dir stringByAppendingPathComponent:BACKGROUND_IMAGE_FILENAME];
}

+(NSString *) getChatDataFilenameForSpot: (NSString *) spot {
    return [self getFilename:[CHAT_DATA_PREFIX stringByAppendingString:spot]];
}

+(NSString*)getPublicKeyFilenameForUsername: (NSString *) username version: (NSString *)version {
    NSString * dir = [self getPublicKeyDirectoryForUsername:username];
    return [dir stringByAppendingPathComponent:[version stringByAppendingPathExtension:PUBLIC_KEYS_EXTENSION]];
    
}
+(NSString*)getPublicKeyDirectoryForUsername: (NSString *) username  {
    NSString * dir = [self getDirectoryForUser:[[IdentityController sharedInstance] getLoggedInUser] ];
    NSString * pkdir = [[dir stringByAppendingPathComponent:PUBLIC_KEYS_DIR] stringByAppendingPathComponent:[username caseInsensitivize]];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:pkdir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    
    return pkdir;
}


+(void) wipeDataForUsername: (NSString *) username friendUsername: (NSString *) friendUsername {
    NSError * error;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self getPublicKeyDirectoryForUsername:friendUsername] error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    
    NSString * spot = [ChatUtils getSpotUserA:username userB:friendUsername];
    NSString * messageFile = [self getChatDataFilenameForSpot:spot];
    
    DDLogInfo( @"wiping data for username: %@, friendname: %@, path: %@", username,friendUsername,messageFile);
    //file manager thread safe supposedly
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    BOOL wiped = [fileMgr removeItemAtPath:messageFile error:nil];
    
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
    
}

+(void) wipeIdentityData: (NSString *) username preserveBackedUpIdentity: (BOOL) preserveBackedUpIdentity {
    //file manager thread safe supposedly
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    BOOL wiped;
    
    // this doesn't wipe out the backed up identity
    // is this a bug?  the preserveBackedUpIdentity flag will
    // take care of preserving the backed up identity
    // if we choose to delete it at a future time
    
    //remove identity file
    NSString * identityFile = [self getIdentityFile:username];
    
    DDLogInfo( @"wiping identity file for username: %@,  path: %@", username,identityFile);
    wiped = [fileMgr removeItemAtPath:identityFile error:nil];
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
    
    //wipe data (chats, keys, etc.)
    NSString * identityDataDir = [self getDirectoryForUser:username];
    
    DDLogInfo( @"wiping data for username: %@,  path: %@", username,identityDataDir);
    wiped = [fileMgr removeItemAtPath:identityDataDir error:nil];
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
}

+(NSString *) getFilename: (NSString *) filename {
    return [self getFilename:filename forUser:[[IdentityController sharedInstance] getLoggedInUser] ];
}

+(NSString *) getFilename: (NSString *) filename forUser: (NSString *) user {
    if (user) {
        NSString * dir = [self getDirectoryForUser:user];
        return [dir stringByAppendingPathComponent:[[filename caseInsensitivize] stringByAppendingPathExtension:STATE_EXTENSION]];
    }
    
    return nil;
}
+(NSString *) getIdentityDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:IDENTITIES_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getUploadsDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:UPLOADS_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getSecretsDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:SECRETS_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getLatestVersionsDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:LATEST_VERSIONS_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getIdentityFile: (NSString *) username {
    NSString * caseun =[username caseInsensitivize];
    NSString * filename = [caseun stringByAppendingPathExtension:IDENTITY_EXTENSION];
    return [[self getIdentityDir ] stringByAppendingPathComponent:filename];
}

+(NSString *) getIdentityFileDocuments: (NSString *) username {
    NSString * caseun =[username caseInsensitivize];
    NSString * filename = [caseun stringByAppendingPathExtension:IDENTITY_EXTENSION];
    return [[self getDocumentsDir ] stringByAppendingPathComponent:filename];
}

+(NSString *) getSecretsFile: (NSString *) username {
    NSString * filename = [[username caseInsensitivize] stringByAppendingPathExtension:SECRET_EXTENSION];
    return [[self getSecretsDir ] stringByAppendingPathComponent:filename];
}

+(NSString *) getLatestVersionsFile: (NSString *) username {
    NSString * filename = [[username caseInsensitivize] stringByAppendingPathExtension:LATEST_VERSIONS_EXTENSION];
    return [[self getLatestVersionsDir ] stringByAppendingPathComponent:filename];
}

+(NSString *) getDirectoryForUser: (NSString *) user {
    NSString * dir = [[[FileController getAppSupportDir] stringByAppendingPathComponent:STATE_DIR ] stringByAppendingPathComponent:[user caseInsensitivize]];
    NSError * error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogVerbose(@"%@", error.localizedDescription);
    }
    return  dir;
}

+(NSString *) getBgImagesDirectoryForUser: (NSString *) user {
    NSString * dir = [[[FileController getAppSupportDir] stringByAppendingPathComponent:BG_IMAGES_DIR ] stringByAppendingPathComponent:[user caseInsensitivize]];
    NSError * error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogVerbose(@"%@", error.localizedDescription);
    }
    return  dir;
}

+(NSDictionary *) loadSharedSecretsForUsername: (NSString *) username withPassword: (NSString *) password {
    NSString * filePath = [self getFilename:SECRETS_FILENAME forUser:username];
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data) {
        
        //NSError* error = nil;
        NSData * secrets = [EncryptionController decryptData: data withPassword:password];
        if (secrets) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:secrets];
        }
    }
    
    return nil;
    
}

+(void) saveSharedSecrets:(NSDictionary *) sharedSecretsDict forUsername: (NSString *) username withPassword: (NSString *) password{
    NSString * filePath = [self getFilename:SECRETS_FILENAME forUser:username];
    NSData * secretData = [NSKeyedArchiver archivedDataWithRootObject:sharedSecretsDict];
    
    NSData * encryptedSecretData = [EncryptionController encryptData:secretData withPassword:password];
    [encryptedSecretData writeToFile:filePath atomically:TRUE];
}

+(void) saveLatestVersions:(NSDictionary *) latestVersionsDict forUsername: (NSString *) username {
    NSString * filePath = [self getFilename:LATEST_VERSIONS_FILENAME forUser:username];
    NSData * latestVersions = [NSKeyedArchiver archivedDataWithRootObject:latestVersionsDict];
    [latestVersions writeToFile:filePath atomically:TRUE];
}

+(void) saveCookie:(NSHTTPCookie *) cookie forUsername: (NSString *) username withPassword: (NSString *) password {
    DDLogInfo(@"saveCookie, username: %@, cookie: %@", username, cookie);
    NSString * filePath = [self getFilename:COOKIE_FILENAME forUser:username];
    NSData * secretData = [NSKeyedArchiver archivedDataWithRootObject:cookie];
    
    NSData * encryptedSecretData = [EncryptionController encryptData:secretData withPassword:password];
    [encryptedSecretData writeToFile:filePath atomically:TRUE];
}

+(NSHTTPCookie *) loadCookieForUsername: (NSString *) username password: password {
    NSString * filePath = [self getFilename:COOKIE_FILENAME forUser:username];
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data) {
        
        //NSError* error = nil;
        NSData * secrets = [EncryptionController decryptData: data withPassword:password];
        if (secrets) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:secrets];
        }
    }
    
    return nil;
}

+(NSDictionary *) loadLatestVersionsForUsername: (NSString *) username {
    NSString * filePath = [self getFilename:LATEST_VERSIONS_FILENAME forUser:username];
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data) {        
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    
    return nil;
    
}

+(void) deleteDataForUsername: (NSString *) username; {
    NSString * filePath = [self getFilename:SECRETS_FILENAME forUser:username];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    filePath = [self getFilename:LATEST_VERSIONS_FILENAME forUser:username];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    filePath = [self getFilename:COOKIE_FILENAME forUser:username];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    
}

+(BOOL) isGzipCompressed: (NSData *) data {
    if (!data ||data.length < 18) {
        return NO;
    }
    else {
        unsigned char * bytes = (unsigned char *)[data bytes];
        return ((bytes[0] == GZIP_MAGIC_1) && (bytes[1] == GZIP_MAGIC_2));
    }
}

+(NSData *) gunzipIfNecessary: (NSData *) identityBytes {
    if ([self isGzipCompressed:identityBytes]) {
        return [identityBytes gzipInflate];
    }
    return identityBytes;
}

+(void) wipeAllState {
    DDLogInfo( @"wiping all data"); //except bg images
    
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    [fileMgr removeItemAtPath:[self getUploadsDir] error:nil];
    [fileMgr removeItemAtPath:[[FileController getAppSupportDir] stringByAppendingPathComponent:STATE_DIR ] error:nil];
    [fileMgr removeItemAtPath:[self getCacheDir] error:nil];
}

+(void) deleteOldSecrets {
    BOOL deleted = [[NSUserDefaults standardUserDefaults] boolForKey:@"deletedOldSecrets"];
    if (!deleted) {
        NSString * secretsPath = [self getSecretsDir];
        NSString * latestVersionsPath = [self getLatestVersionsDir];
        [[NSFileManager defaultManager] removeItemAtPath:secretsPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:latestVersionsPath error:nil];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"deletedOldSecrets"];
    }
}


@end
