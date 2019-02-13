//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "GetPublicKeysOperation.h"
#import "NetworkController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "NSData+Base64.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface GetPublicKeysOperation()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * version;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end




@implementation GetPublicKeysOperation

-(id) initWithUsername: (NSString *) username version: (NSString *) version completionCallback:(void(^)(PublicKeys *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.username = username;
        self.version = version;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    NSInteger currentVersion = [_version integerValue];
    NSInteger wantedVersion = currentVersion;
    
    PublicKeys * keys = nil;
    PublicKeys * validatedKeys = nil;
    NSInteger validatedKeyVersion = 0;
    
    NSMutableDictionary * dsaKeys = [[NSMutableDictionary alloc] init];
    NSMutableDictionary * resultKeys = [[NSMutableDictionary alloc] init];
    
    while (currentVersion > 0) {
        NSString * sCurrentVersion = [@(currentVersion) stringValue];
        keys = [[IdentityController sharedInstance] loadPublicKeysUsername: _username version:  sCurrentVersion];
        if (keys) {
            validatedKeys = keys;
            validatedKeyVersion = currentVersion;
            break;
        }
        currentVersion--;
    }
    

    if (validatedKeys && wantedVersion == validatedKeyVersion) {
        DDLogInfo(@"Loaded public keys from disk for user: %@, version: %@", _username, _version);
        [self finish:keys];
        return;
    }
        
    [[NetworkController sharedInstance]
     getPublicKeys2ForUsername: self.username
     andVersion: [@(validatedKeyVersion+1) stringValue]
     successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         
         if (JSON) {
             for (NSInteger i=0;i < [JSON count]; i++) {
                 NSDictionary * jsonKeys = [JSON objectAtIndex:i];
                 NSString * sReadVersion = [jsonKeys objectForKey:@"version"];
                 NSString * spubECDSA = [jsonKeys objectForKey:@"dsaPub"];
                 ECDSAPublicKey * dsaPub = [EncryptionController recreateDsaPublicKey:spubECDSA];
                 [dsaKeys setObject:[NSValue valueWithPointer:dsaPub] forKey:sReadVersion];
                 [resultKeys setObject:jsonKeys forKey:sReadVersion];
             }
             
             NSDictionary * wantedKey = [resultKeys objectForKey:_version];
             if (![wantedKey objectForKey:@"clientSig"]) {
                 DDLogInfo(@"validating username: %@, version: %@, keys using v1 code", _username, _version);
                 [self finish:[self getPublicKeysForUsername:_username version:_version jsonKeys:wantedKey]];
                 return;
             }
             else {
                 DDLogInfo(@"validating username: %@, version: %@, keys using v2 code", _username, _version);
                 
                 ECDSAPublicKey * previousDsaKey = nil;
                 if (validatedKeys) {
                     previousDsaKey = [validatedKeys dsaPubKey];
                 }
                 else {
                     [[dsaKeys objectForKey:@"1"] getValue:&previousDsaKey];
                 }
                 
                 NSString * sDhPub = nil;
                 NSString * sDsaPub = nil;
                 
                 for (NSInteger validatingVersion = validatedKeyVersion + 1;validatingVersion <= wantedVersion; validatingVersion++) {
                     NSString * sValidatingVersion = [@(validatingVersion) stringValue];
                     NSDictionary * jsonKey = [resultKeys objectForKey: sValidatingVersion];
                     sDhPub = [jsonKey objectForKey:@"dhPub"];
                     sDsaPub = [jsonKey objectForKey:@"dsaPub"];
                     
                     BOOL verified = [EncryptionController verifySigUsingKey:[EncryptionController serverPublicKey] signature:[NSData dataFromBase64String:[jsonKey objectForKey:@"serverSig"]] username:_username version:validatingVersion dhPubKey:sDhPub dsaPubKey:sDsaPub];
                     
                     if (!verified) {
                         DDLogWarn(@"server signature check failed");
                         [self finish:nil];
                         return;
                     }
                     
                     verified = [EncryptionController verifySigUsingKey:previousDsaKey signature:[NSData dataFromBase64String:[jsonKey objectForKey:@"clientSig"]] username:_username version:validatingVersion dhPubKey:sDhPub dsaPubKey:sDsaPub];
                     if (!verified) {
                         DDLogWarn(@"client signature check failed");
                         [self finish:nil];
                         return;
                     }

                     [[IdentityController sharedInstance] savePublicKeys: jsonKey  username: _username version: sValidatingVersion];
                     [[dsaKeys objectForKey: sValidatingVersion] getValue:&previousDsaKey];
                 }
                 
                 ECDHPublicKey * dhPub = [EncryptionController recreateDhPublicKey:sDhPub];
                 ECDSAPublicKey * dsaPub;
                 [[dsaKeys objectForKey:_version] getValue:&dsaPub];
                 
                 PublicKeys* pk = [[PublicKeys alloc] init];
                 pk.dhPubKey = dhPub;
                 pk.dsaPubKey = dsaPub;
                 pk.version = _version;
                 pk.lastModified = [NSDate date];
                 
                 [self finish:pk];

             }
         }
         else {
             [self finish:nil];
         }
         
     } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
         
         DDLogVerbose(@"response failure: %@",  Error);
         [self finish:nil];
         
     }];
    
    
}


-(PublicKeys *) getPublicKeysForUsername: (NSString *) username version: (NSString *) version jsonKeys: (NSDictionary *) JSON {
    
    if (JSON) {
        NSString * version = [JSON objectForKey:@"version"];
        if (![_version isEqualToString:version]) {
            DDLogWarn(@"public key versions do not match");
            return nil;
        }
        
        
        DDLogInfo(@"verifying public keys for %@", _username);
        BOOL verified = [[IdentityController sharedInstance  ] verifyPublicKeys: JSON];
        
        if (!verified) {
            DDLogWarn(@"could not verify public keys!");
            return nil;
        }
        else {
            DDLogInfo(@"public keys verified against server signature");
            
            //recreate public keys
            NSDictionary * jsonKeys = JSON;
            
            NSString * spubDH = [jsonKeys objectForKey:@"dhPub"];
            NSString * spubDSA = [jsonKeys objectForKey:@"dsaPub"];
            
            ECDHPublicKey * dhPub = [EncryptionController recreateDhPublicKey:spubDH];
            ECDHPublicKey * dsaPub = [EncryptionController recreateDsaPublicKey:spubDSA];
            
            PublicKeys* pk = [[PublicKeys alloc] init];
            pk.dhPubKey = dhPub;
            pk.dsaPubKey = dsaPub;
            pk.version = _version;
            pk.lastModified = [NSDate date];
            
            //save keys to disk
            [[IdentityController sharedInstance] savePublicKeys: JSON username: _username version:  _version];
            
            DDLogVerbose(@"get public keys calling callback");
            return pk;
        }
    }
    
    return nil;
}

- (void)finish: (PublicKeys *) publicKeys
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(publicKeys);
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
