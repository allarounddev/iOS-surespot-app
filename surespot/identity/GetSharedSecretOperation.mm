//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "GetSharedSecretOperation.h"
#import "GetPublicKeysOperation.h"
#import "GenerateSharedSecretOperation.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "FileController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface GetSharedSecretOperation()
@property (nonatomic) CredentialCachingController * cache;
@property (nonatomic) NSString * ourVersion;
@property (nonatomic) NSString * theirUsername;
@property (nonatomic) NSString * theirVersion;
@property (nonatomic, strong) void(^callback)(NSData *);
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end



@implementation GetSharedSecretOperation

-(id) initWithCache: (CredentialCachingController *) cache
         ourVersion: (NSString *) ourVersion
      theirUsername: (NSString *) theirUsername
       theirVersion: (NSString *) theirVersion
           callback: (CallbackBlock) callback {
    if (self = [super init]) {
        self.cache = cache;
        self.ourVersion = ourVersion;
        self.theirUsername = theirUsername;
        self.theirVersion = theirVersion;
        self.callback = callback;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    DDLogVerbose(@"executing");
    
    
    //see if we have the shared secret cached already
    NSString * sharedSecretKey = [NSString stringWithFormat:@"%@:%@:%@:%@", self.cache.loggedInUsername, self.ourVersion, self.theirUsername, self.theirVersion];
    
    DDLogVerbose(@"checking dictionary for shared secret for:  %@" , sharedSecretKey);
    NSData * sharedSecret = [self.cache.sharedSecretsDict objectForKey:sharedSecretKey];
    
    if (sharedSecret) {
        DDLogVerbose(@"using cached secret for %@", sharedSecretKey);
        [self finish:sharedSecret];
    }
    else {
        DDLogVerbose(@"shared secret not cached");
        SurespotIdentity * identity = [self.cache getLoggedInIdentity];
        if (!identity) {
            [self finish:nil];
            return;
        }
        
        //get public keys out of dictionary
        NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", self.theirUsername, self.theirVersion];
        PublicKeys * publicKeys = [self.cache.publicKeysDict objectForKey:publicKeysKey];
        
        if (publicKeys) {
            DDLogVerbose(@"using cached public keys for %@", publicKeysKey);
            
            GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc]
                                                              initWithOurPrivateKey:[identity getDhPrivateKeyForVersion:_ourVersion]
                                                              theirPublicKey:[publicKeys dhPubKey]
                                                              completionCallback:^(NSData * secret) {
                                                                  //store shared key in dictionary
                                                                  [self.cache cacheSharedSecret: secret forKey: sharedSecretKey];
                                                                  [self finish:secret];
                                                              }];
            
            [self.cache.genSecretQueue addOperation:sharedSecretOp];
        }
        else {
            DDLogVerbose(@"public keys not cached for %@", publicKeysKey );
            
            //get the public keys we need
            GetPublicKeysOperation * pkOp = [[GetPublicKeysOperation alloc] initWithUsername:self.theirUsername version:self.theirVersion completionCallback:
                                             ^(PublicKeys * keys) {
                                                 if (keys) {
                                                     DDLogVerbose(@"caching public keys for %@", publicKeysKey);
                                                     //store keys in dictionary
                                                     [self.cache.publicKeysDict setObject:keys forKey:publicKeysKey];
                                                     
                                                     NSString * theirVersion = [self.cache.latestVersionsDict objectForKey:_theirUsername];
                                                     //if the version is greater than what we have then cache it
                                                     if (!theirVersion || [theirVersion integerValue] < [keys.version integerValue]) {
                                                         DDLogVerbose(@"caching key version: %@ for username: %@", keys.version, _theirUsername);
                                                         
                                                         [self.cache.latestVersionsDict setObject:keys.version forKey:_theirUsername];
                                                     }
                                                     
                                                     
                                                     GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc]
                                                                                                       initWithOurPrivateKey:[identity getDhPrivateKeyForVersion:_ourVersion]
                                                                                                       theirPublicKey:[keys dhPubKey]
                                                                                                       completionCallback:^(NSData * secret) {
                                                                                                           //store shared key in dictionary
                                                                                                           DDLogVerbose(@"caching shared secret for %@", sharedSecretKey);                                                                                                          [self.cache cacheSharedSecret: secret forKey: sharedSecretKey];
                                                                                                           [self finish:secret];
                                                                                                       }];
                                                     
                                                     [self.cache.genSecretQueue addOperation:sharedSecretOp];
                                                 }
                                                 else {
                                                     //failed to get keys, return nill
                                                     DDLogVerbose(@"could not get public key for %@", publicKeysKey );
                                                     [self finish:nil];
                                                 }
                                                 
                                                 
                                             }];
            
            [self.cache.publicKeyQueue addOperation:pkOp];
        }
    }
}

- (void)finish: (NSData *) secret
{
    DDLogVerbose(@"finished");
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(secret);
    _callback = nil;
    _cache = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
