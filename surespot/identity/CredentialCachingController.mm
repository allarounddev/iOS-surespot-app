//
//  CredentialCachingController.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "CredentialCachingController.h"
#import "GetSharedSecretOperation.h"
#import "GetKeyVersionOperation.h"
#import "NetworkController.h"
#import "FileController.h"
#import "DDLog.h"
#import "GetPublicKeysOperation.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface CredentialCachingController()
@property (nonatomic, strong) NSOperationQueue * keyVersionQueue;
@property (nonatomic, strong) NSOperationQueue * getSecretQueue;
@property (nonatomic, strong) NSMutableDictionary * cookiesDict;
@property (nonatomic, retain) NSMutableDictionary * identitiesDict;
@end

@implementation CredentialCachingController

+(CredentialCachingController*)sharedInstance
{
    static CredentialCachingController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.sharedSecretsDict = [[NSMutableDictionary alloc] init];
        sharedInstance.publicKeysDict = [[NSMutableDictionary alloc] init];
        sharedInstance.latestVersionsDict = [[NSMutableDictionary alloc] init];
        sharedInstance.cookiesDict = [[NSMutableDictionary alloc] init];
        sharedInstance.identitiesDict = [[NSMutableDictionary alloc] init];
        sharedInstance.genSecretQueue = [[NSOperationQueue alloc] init];
        sharedInstance.publicKeyQueue = [[NSOperationQueue alloc] init];
        sharedInstance.getSecretQueue = [[NSOperationQueue alloc] init];
        [sharedInstance.getSecretQueue setMaxConcurrentOperationCount:1];
        sharedInstance.keyVersionQueue = [NSOperationQueue new];
        [sharedInstance.keyVersionQueue setMaxConcurrentOperationCount:1];
    });
    
    return sharedInstance;
}



-(void) getSharedSecretForOurVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion callback: (CallbackBlock) callback {
    
    DDLogVerbose(@"getSharedSecretForOurVersion, queue size: %d", [_getSecretQueue operationCount] );
    
    GetSharedSecretOperation * op = [[GetSharedSecretOperation alloc] initWithCache:self ourVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback:callback];
    
    [self.getSecretQueue addOperation:op];
    
}

-(void) loginIdentity: (SurespotIdentity *) identity password: (NSString *) password cookie: (NSHTTPCookie *) cookie{
    self.loggedInUsername = identity.username;
    
    //load encrypted shared secrets from disk if we have a password
    if (password) {
        [self loadSharedSecretsForUsername:identity.username password:password];
        
        if (cookie) {
            [FileController saveCookie:cookie forUsername:identity.username withPassword:password];
            [_cookiesDict setObject:cookie forKey:identity.username];
        }
    }
    
    _latestVersionsDict = [NSMutableDictionary dictionaryWithDictionary:[FileController loadLatestVersionsForUsername:identity.username]];
    DDLogVerbose(@"loaded %d latest versions from disk", [_latestVersionsDict count]);
    
    [self updateIdentity:identity onlyIfExists:NO];
    
}

-(void) loadSharedSecretsForUsername: (NSString *) username password: (NSString *) password {
    if (password) {
        NSDictionary * secrets  =  [FileController loadSharedSecretsForUsername: username withPassword:password];
        [_sharedSecretsDict addEntriesFromDictionary:secrets];
        DDLogVerbose(@"loaded %d encrypted secrets from disk", [secrets count]);
    }
}

-(void) updateIdentity: (SurespotIdentity *) identity onlyIfExists: (BOOL) onlyIfExists {
    
    if ([_identitiesDict objectForKey:identity.username] || !onlyIfExists) {
        [_identitiesDict setObject:identity forKey:identity.username];
        
        //add all the public keys for this identity to the cache
        for (IdentityKeys * keys in [identity.keyPairs allValues]) {
            NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", identity.username,  keys.version];
            PublicKeys * publicKeys = [[PublicKeys alloc] init];
            
            //make new copy of public keys
            publicKeys.version = keys.version;
            publicKeys.dhPubKey = [EncryptionController createPublicDHFromPrivKey:keys.dhPrivKey];
            publicKeys.dsaPubKey = [EncryptionController createPublicDSAFromPrivKey:keys.dsaPrivKey];
            [_publicKeysDict setObject:publicKeys forKey:publicKeysKey];
        }
    }
}


-(void) logout {
    if (_loggedInUsername) {
        [self saveSharedSecrets];
        //only remove objects for the logging out user
        NSMutableArray * keysToRemove = [[NSMutableArray alloc] init];
        
        for (NSString * key in [_sharedSecretsDict keyEnumerator]) {
            if ([key hasPrefix:_loggedInUsername]) {
                DDLogVerbose(@"removing shared secret key: %@", key);
                [keysToRemove addObject:key];
            }
        }
        
        [_sharedSecretsDict removeObjectsForKeys:keysToRemove];
        
        [_identitiesDict removeObjectForKey:_loggedInUsername];
        _loggedInUsername = nil;
    }
}

-(void) saveSharedSecrets {
    //save encrypted shared secrets to disk if we have a password in the keychain for this user
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:_loggedInUsername];
    if (password) {
        NSMutableDictionary * ourSecrets = [[NSMutableDictionary alloc] init];
        for (NSString * key in [_sharedSecretsDict keyEnumerator]) {
            if ([key hasPrefix:_loggedInUsername]) {
                DDLogVerbose(@"saving shared secret key: %@", key);
                [ourSecrets setObject:[_sharedSecretsDict objectForKey:key] forKey:key];
            }
        }
        
        
        [FileController saveSharedSecrets: ourSecrets forUsername: _loggedInUsername withPassword:password];
        DDLogVerbose(@"saved %d encrypted secrets to disk", [ourSecrets count]);
    }
    
}

-(void) saveLatestVersions {
    
    [FileController saveLatestVersions: _latestVersionsDict forUsername: _loggedInUsername];
    DDLogVerbose(@"saved %d latest versions to disk", [_latestVersionsDict count]);
    
    
}

-(void) clearUserData: (NSString *) friendname {
    [_latestVersionsDict removeObjectForKey:friendname];
    
    //for ref
    //    NSString * sharedSecretKey = [NSString stringWithFormat:@"%@:%@:%@:%@",loggedinuser, self.ourVersion, self.theirUsername, self.theirVersion];
    //      NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", self.theirUsername, self.theirVersion];
    
    NSMutableArray * keysToRemove = [NSMutableArray new];
    //iterate through shared secret keys and delete those that match the passed in user
    for (NSString * key in [_sharedSecretsDict allKeys]) {
        NSArray * keyComponents = [key componentsSeparatedByString:@":"];
        if ([[keyComponents objectAtIndex:2] isEqualToString:friendname] ) {
            DDLogVerbose(@"removing shared secret for: %@", key);
            [keysToRemove addObject:key];
        }
    }
    
    [_sharedSecretsDict removeObjectsForKeys:keysToRemove];
    
    keysToRemove = [NSMutableArray new];
    //iterate through public keys and delete those that match the passed in user
    for (NSString * key in [_publicKeysDict allKeys]) {
        NSArray * keyComponents = [key componentsSeparatedByString:@":"];
        if ([[keyComponents objectAtIndex:0] isEqualToString:friendname] ) {
            DDLogVerbose(@"removing public key for: %@", key);
            [keysToRemove addObject:key];
        }
    }
    
    [_publicKeysDict removeObjectsForKeys:keysToRemove];
    
    [self saveSharedSecrets];
    [self saveLatestVersions];
    
}


-(void) clearIdentityData:(NSString *) username {
    if ([username isEqualToString:_loggedInUsername]) {
        DDLogVerbose(@"purging cached identity data from RAM for: %@",  username);
        [_sharedSecretsDict removeAllObjects];
        [_publicKeysDict removeAllObjects];
        [_latestVersionsDict removeAllObjects];
        [_identitiesDict removeObjectForKey:username];
        [_cookiesDict removeObjectForKey:username];
    }
}

- (void) getLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback {
    DDLogVerbose(@"getLatestVersionForUsername, queue size: %d", [_keyVersionQueue operationCount] );
    
    GetKeyVersionOperation * op = [[GetKeyVersionOperation alloc] initWithCache:self username:username completionCallback: callback];
    [self.getSecretQueue addOperation:op];
    
    
}

-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString * ) version {
    if (username && version) {
        NSString * latestVersion = [_latestVersionsDict objectForKey:username];
        if (!latestVersion || [version integerValue] > [latestVersion integerValue]) {
            DDLogVerbose(@"updating latest key version to %@ for %@", version, username);
            [_latestVersionsDict setObject:version forKey:username];
            [self saveLatestVersions];
        }
    }
}


-(void) cacheSharedSecret: secret forKey: sharedSecretKey {
    [_sharedSecretsDict setObject:secret forKey:sharedSecretKey];
    [self saveSharedSecrets];
}

-(SurespotIdentity *) getLoggedInIdentity {
    return [self getIdentityForUsername:_loggedInUsername password:nil];
}

-(SurespotIdentity *) getIdentityForUsername: (NSString *) username password: (NSString *) password {
    SurespotIdentity * identity = [_identitiesDict objectForKey:username];
    if (!identity) {
        if (!password) {
            password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
        }
        
        if (password) {
            identity = [[IdentityController sharedInstance] loadIdentityUsername:username password:password];
            if (identity) {
                [self updateIdentity:identity onlyIfExists:false];
            }
        }
    }
    return identity;
}

-(NSHTTPCookie *) getCookieForUsername:(NSString *)username {
    DDLogVerbose(@"getCookieForUsername: %@", username);
    NSHTTPCookie * cookie = nil;
    if (username) {
        cookie = [_cookiesDict objectForKey:username];
        if (!cookie) {
            NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
            if (password) {
                
                cookie = [FileController loadCookieForUsername:username password:password];
                if (cookie) {
                    DDLogVerbose(@"getCookieForUsername, caching cookie: %@", username);
                    [_cookiesDict setObject:cookie forKey:username];
                }
            }
        }
    }
    DDLogVerbose(@"getCookieForUsername cookie: %@", cookie);
    return cookie;
}

-(BOOL) setSessionForUsername: (NSString *) username {
    SurespotIdentity * identity = [self getIdentityForUsername:username password:nil];
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    
    BOOL hasCookie = NO;
    NSHTTPCookie * cookie = [self getCookieForUsername:username];
    NSDate * dateNow = [NSDate date];
    if (cookie && cookie.expiresDate.timeIntervalSinceReferenceDate > ([dateNow timeIntervalSinceReferenceDate] - 60 * 60 * 1000)) {
        hasCookie = YES;
    }
    
    BOOL sessionSet = identity && (password || hasCookie);
    if (sessionSet) {
        _loggedInUsername = username;
        
        if (password) {
            [self loadSharedSecretsForUsername:username password:password];
        }
    }
    
    return sessionSet;
}

@end
