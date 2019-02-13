//
//  IdentityController.h
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotIdentity.h"
#import "IdentityKeys.h"
#import "PublicKeys.h"
#import "SurespotConstants.h"


@interface IdentityController : NSObject
+(IdentityController*)sharedInstance;


- ( SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password;
- (void) createIdentityWithUsername: (NSString *) username andPassword: (NSString *) password andSalt: (NSString *) salt andKeys: (IdentityKeys *) keys cookie: (NSHTTPCookie *) cookie;
-(NSArray *) getIdentityNames;
- (void) userLoggedInWithIdentity: (SurespotIdentity *) identity password: (NSString *) password cookie:(NSHTTPCookie *) cookie reglogin: (BOOL) relogin;
- (NSString *) getLoggedInUser;
- (NSString *) getOurLatestVersion;
- (void) getTheirLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback;
-(BOOL) verifyPublicKeys: (NSDictionary *) keys;
-(PublicKeys *) loadPublicKeysUsername: (NSString * ) username version: (NSString *) version;
-(void) savePublicKeys: (NSDictionary * ) keys username: (NSString *)username version: (NSString *)version;
-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString * ) version;
-(void) logout;
-(NSString *) getStoredPasswordForIdentity: (NSString *) username;
-(void) storePasswordForIdentity: (NSString *) username password: (NSString *) password;
-(void) clearStoredPasswordForIdentity: (NSString *) username;
- (NSString * ) identityNameFromFile: (NSString *) file;
-(void) importIdentityData: (NSData *) identityData username: (NSString *) username password: (NSString *) password callback: (CallbackBlock) callback;
-(void) exportIdentityDataForUsername: (NSString *) username password: (NSString *) password callback: (CallbackErrorBlock) callback;
-(void) rollKeysForUsername: (NSString *) username
                   password: (NSString *) password
                 keyVersion: (NSString *)  keyVersion
                       keys: (IdentityKeys *) keys;
-(void) setExpectedKeyVersionForUsername: (NSString *) username version: (NSString *) version;
-(void) removeExpectedKeyVersionForUsername: (NSString *) username;
-(void) deleteIdentityUsername: (NSString *) username preserveBackedUpIdentity: (BOOL) preserveBackedUpIdentity;
-(void) updatePasswordForUsername: (NSString *) username currentPassword: (NSString *) currentPassword newPassword: (NSString *) newPassword newSalt: (NSString *) newSalt;
-(NSInteger) getIdentityCount;
-(void) exportIdentityToDocumentsForUsername: (NSString *) username password: (NSString *) password callback: (CallbackErrorBlock) callback;
-(BOOL) importIdentityFilename: (NSString *) filePath username: (NSString * ) username password: (NSString *) password;
-(SurespotIdentity *) loadIdentityUsername: (NSString * ) username password: (NSString *) password;
-(NSString *) getLastLoggedInUser;
-(NSDictionary *) updateSignatures;
@end

