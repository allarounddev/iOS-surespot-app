//
//  NetworkController.m
//  surespot
//
//  Created by Adam on 6/16/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "IdentityController.h"
#import "NetworkController.h"
#import "ChatUtils.h"
#import "DDLog.h"
#import "NSData+Base64.h"
//#import "NSString+SBJSON.h"
#import "EncryptionController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface NetworkController()
@property (nonatomic, strong) NSString * baseUrl;
@property (atomic, assign) BOOL loggedOut;
@end

@implementation NetworkController

+(NetworkController*)sharedInstance
{
    static NetworkController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        
    });
    
    return sharedInstance;
}

-(NetworkController*)init
{
    NSString * baseUrl = serverSecure ?
    [NSString stringWithFormat: @"https://%@:%d", serverBaseIPAddress, serverPort] :
    [NSString stringWithFormat: @"http://%@:%d", serverBaseIPAddress, serverPort];
    
    //call super init
    self = [super initWithBaseURL:[NSURL URLWithString: baseUrl]];
    
    if (self != nil) {
        _baseUrl = baseUrl;
        
        // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
        [self setDefaultHeader:@"Accept-Charset" value:@"utf-8"];
        [self setDefaultHeader:@"User-Agent" value:[NSString stringWithFormat:@"%@/%@ (%@; CPU iPhone OS 7_0_4; Scale/%0.2f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], (__bridge id)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey) ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(HTTPOperationDidFinish:) name:AFNetworkingOperationDidFinishNotification object:nil];
        
        self.parameterEncoding = AFJSONParameterEncoding;
    }
    
    return self;
}


//handle 401s globally
- (void)HTTPOperationDidFinish:(NSNotification *)notification {
    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    
    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
        return;
    }
    
    if ([operation.response statusCode] == 401) {
        DDLogInfo(@"path components: %@", operation.request.URL.pathComponents[1]);
        //ignore on logout
        if (![operation.request.URL.pathComponents[1] isEqualToString:@"logout"]) {
            DDLogInfo(@"received 401");
            [self setUnauthorized];
        }
        else {
            DDLogInfo(@"logout 401'd");
        }
    }
}

-(void) setUnauthorized {
    _loggedOut = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"unauthorized" object: nil];
}

-(void) clearCookies {
    //clear the cookie store
    for (NSHTTPCookie * cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    }
}

-(void) loginWithUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
             successBlock:(JSONCookieSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    [self clearCookies];
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    [self addPurchaseReceiptToParams:params];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"login" parameters: params];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        NSHTTPCookie * cookie = [self extractConnectCookie];
        if (cookie) {
            successBlock(request, response, JSON, cookie);
        }
        else {
            failureBlock(request, response, nil, nil);
        }
        
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        failureBlock(request, response, error, JSON);
    } ];
    
    
    [operation start];
    
}

-(BOOL) reloginWithUsername:(NSString*) username successBlock:(JSONCookieSuccessBlock) successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    DDLogInfo(@"relogin: %@", username);
    //if we have password login again
    NSString * password = nil;
    
    if (username) {
        password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    }
    
    if (username && password) {
        dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        
        dispatch_async(q, ^{
            DDLogVerbose(@"getting identity");
            SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
            DDLogVerbose(@"got identity");
            
            if (!identity) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failureBlock(nil,nil,nil,nil);
                });
                return;
            }
            
            DDLogVerbose(@"creating signature");
            
            NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
            NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
            NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
            
            NSData * signature = [EncryptionController signUsername:identity.username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
            NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
            NSString * signatureString = [signature SR_stringByBase64Encoding];
            
            DDLogInfo(@"logging in to server");
            [[NetworkController sharedInstance]
             loginWithUsername:identity.username
             andPassword:passwordString
             andSignature: signatureString
             successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSHTTPCookie * cookie) {
                 DDLogVerbose(@"login response: %d",  [response statusCode]);
                 [[IdentityController sharedInstance] userLoggedInWithIdentity:identity password: password cookie: cookie reglogin:YES];
                 successBlock(request, response, JSON, cookie);
             }
             failureBlock: failureBlock];
        });
        
        return YES;
        
        
    }
    else {
        return NO;
    }
}

-(void) createUser2WithUsername:(NSString *)username derivedPassword:(NSString *)derivedPassword dhKey:(NSString *)encodedDHKey dsaKey:(NSString *)encodedDSAKey authSig:(NSString *)authSig clientSig:(NSString *)clientSig successBlock:(HTTPCookieSuccessBlock)successBlock failureBlock:(HTTPFailureBlock)failureBlock {
    
    [self clearCookies];
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   derivedPassword,@"password",
                                   authSig, @"authSig",
                                   encodedDHKey, @"dhPub",
                                   encodedDSAKey, @"dsaPub",
                                   versionString, @"version",
                                   clientSig, @"clientSig",
                                   @"ios", @"platform", nil];
    
    [self addPurchaseReceiptToParams:params];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"users2" parameters: params];
    
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSHTTPCookie * cookie = [self extractConnectCookie];
        if (cookie) {
            successBlock(operation, responseObject, cookie);
        }
        else {
            failureBlock(operation, nil);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failureBlock(operation, error);
    }];
    
    [operation start];
}


-(NSHTTPCookie *) extractConnectCookie {
    //save the cookie
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    
    for (NSHTTPCookie *cookie in cookies)
    {
        if ([cookie.name isEqualToString:@"connect.sid"]) {
            _loggedOut = NO;
            return cookie;
        }
    }
    
    return nil;
    
}

-(void) getFriendsSuccessBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSURLRequest *request = [self requestWithMethod:@"GET" path:@"friends" parameters:nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    operation.JSONReadingOptions = NSJSONReadingMutableContainers;
    [operation start];
}

-(void) inviteFriend: (NSString *) friendname successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat: @"invite/%@",friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getKeyVersionForUsername:(NSString *)username successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock
{
    NSString * path = [[NSString stringWithFormat: @"keyversion/%@",username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

- (void) getPublicKeys2ForUsername:(NSString *)username andVersion:(NSString *)version successBlock:(JSONSuccessBlock)successBlock failureBlock:(JSONFailureBlock) failureBlock{
    NSURLRequest *request = [self buildPublicKeyRequestForUsername:username version:version];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure: failureBlock];
    
    //dont't need this on main thread
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
}

-(NSURLRequest *) buildPublicKeyRequestForUsername: (NSString *) username version: (NSString *) version {
    NSString * path = [[NSString stringWithFormat: @"publickeys/%@/since/%@",username, version]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ;
    NSURLRequest *request = [self requestWithMethod:@"GET" path: path parameters: nil];
    return request;
}

-(void) getMessageDataForUsername:(NSString *)username andMessageId:(NSInteger)messageId andControlId:(NSInteger) controlId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagedataopt/%@/%u/%u", username, messageId, controlId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    [operation start];
    
}

-(void) respondToInviteName:(NSString *) friendname action: (NSString *) action successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"invites/%@/%@", friendname, action] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) getLatestDataSinceUserControlId: (NSInteger) latestUserControlId spotIds: (NSArray *) spotIds successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    NSMutableDictionary *params = nil;
    if ([spotIds count] > 0) {
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:spotIds options:0 error:nil];
        NSString * jsonString =[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        params = [NSMutableDictionary dictionaryWithObjectsAndKeys:jsonString,@"spotIds", nil];
    }
    DDLogVerbose(@"GetLatestData: params; %@", params);
    
    [self addPurchaseReceiptToParams:params];
    
    NSString * path = [NSString stringWithFormat:@"optdata/%d", latestUserControlId];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters: params];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    
    [operation start];
}



-(void) logout {
    //send logout
    if (!_loggedOut) {
        DDLogInfo(@"logout");
        NSURLRequest *request = [self requestWithMethod:@"POST" path:@"logout"  parameters:nil];
        AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
        [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self deleteCookies];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            [self deleteCookies];
        }];
        [operation start];
    }
    
    
}

-(void) deleteCookies {
    //blow cookies away
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:_baseUrl]];
    for (NSHTTPCookie *cookie in cookies)
    {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage]  deleteCookie:cookie];
    }
    
}


-(void) deleteFriend:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"friends/%@", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}


-(void) deleteMessageName:(NSString *) name serverId: (NSInteger) serverid successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%d", name, serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) deleteMessagesUTAI:(NSInteger) utaiId name: (NSString *) name successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesutai/%@/%d", name, utaiId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) userExists: (NSString *) username successBlock: (HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    NSString * path = [[NSString stringWithFormat:@"users/%@/exists", username] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path: path  parameters:nil];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) getEarlierMessagesForUsername: (NSString *) username messageId: (NSInteger) messageId successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"messagesopt/%@/before/%d", username, messageId]  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters: nil];
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock
                                                                                        failure: failureBlock];
    
    [operation start];
}

-(void) validateUsername: (NSString *) username password: (NSString *) password signature: (NSString *) signature successBlock:(HTTPSuccessBlock) successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:username,@"username",password,@"password",signature,@"authSig", nil];
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"validate"  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) postFileStreamData: (NSData *) data
                ourVersion: (NSString *) ourVersion
             theirUsername: (NSString *) theirUsername
              theirVersion: (NSString *) theirVersion
                    fileid: (NSString *) fileid
                  mimeType: (NSString *) mimeType
              successBlock:(JSONSuccessBlock) successBlock
              failureBlock: (JSONFailureBlock) failureBlock
{
    DDLogInfo(@"postFileStream, fileid: %@", fileid);
    NSString * path = [[NSString stringWithFormat:@"images/%@/%@/%@", ourVersion, theirUsername, theirVersion] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request
    = [self multipartFormRequestWithMethod:@"POST"
                                      path: path
                                parameters:nil
                 constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                     
                     [formData appendPartWithFileData:data
                                                 name:@"image"
                                             fileName:fileid mimeType:mimeType];
                     
                 }];
    
    
    // if you want progress updates as it's uploading, uncomment the following:
    //
    // [operation setUploadProgressBlock:^(NSUInteger bytesWritten,
    // long long totalBytesWritten,
    // long long totalBytesExpectedToWrite) {
    //     NSLog(@"Sent %lld of %lld bytes", totalBytesWritten, totalBytesExpectedToWrite);
    // }];
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) postFriendStreamData: (NSData *) data
                  ourVersion: (NSString *) ourVersion
               theirUsername: (NSString *) theirUsername
                          iv: (NSString *) iv
                successBlock:(HTTPSuccessBlock) successBlock
                failureBlock: (HTTPFailureBlock) failureBlock
{
    DDLogInfo(@"postFriendFileStream, iv: %@", iv);
    NSString * path = [[NSString stringWithFormat:@"images/%@/%@", theirUsername, ourVersion] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request
    = [self multipartFormRequestWithMethod:@"POST"
                                      path: path
                                parameters:nil
                 constructingBodyWithBlock: ^(id <AFMultipartFormData>formData) {
                     
                     [formData appendPartWithFileData:data
                                                 name:@"image"
                                             fileName:iv mimeType:MIME_TYPE_IMAGE];
                     
                 }];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    // if you want progress updates as it's uploading, uncomment the following:
    //
    // [operation setUploadProgressBlock:^(NSUInteger bytesWritten,
    // long long totalBytesWritten,
    // long long totalBytesExpectedToWrite) {
    //     NSLog(@"Sent %lld of %lld bytes", totalBytesWritten, totalBytesExpectedToWrite);
    // }];
    
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) setMessageShareable:(NSString *) name
                   serverId: (NSInteger) serverid
                  shareable: (BOOL) shareable
               successBlock:(HTTPSuccessBlock)successBlock
               failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:(shareable ? @"true" : @"false"),@"shareable", nil];
    NSString * path = [[NSString stringWithFormat:@"messages/%@/%d/shareable", name, serverid] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"PUT" path:path  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
    
}

-(void) getKeyTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                  successBlock:(JSONSuccessBlock)successBlock failureBlock: (JSONFailureBlock) failureBlock
{
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"keytoken" parameters: params];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
}


-(void) updateKeys2ForUsername:(NSString *) username
                      password:(NSString *) password
                   publicKeyDH:(NSString *) pkDH
                  publicKeyDSA:(NSString *) pkDSA
                       authSig:(NSString *) authSig
                      tokenSig:(NSString *) tokenSig
                    keyVersion:(NSString *) keyversion
                     clientSig:(NSString *) clientSig
                  successBlock:(HTTPSuccessBlock) successBlock
                  failureBlock:(HTTPFailureBlock) failureBlock
{
    
    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *appBuildString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@:%@", appVersionString, appBuildString];
    
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   pkDH, @"dhPub",
                                   pkDSA, @"dsaPub",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   clientSig, @"clientSig",
                                   keyversion, @"keyVersion",
                                   versionString, @"version",
                                   @"ios", @"platform", nil];
    
    //add apnToken if we have one
    NSData *  apnToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"apnToken"];
    if (apnToken) {
        [params setObject:[ChatUtils hexFromData:apnToken] forKey:@"apnToken"];
    }
    
    NSURLRequest *request = [self requestWithMethod:@"POST" path:@"keys2"  parameters:params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
    
}

-(void) getDeleteTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                     successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"deletetoken" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
    
    
    
}

-(void) deleteUsername:(NSString *) username
              password:(NSString *) password
               authSig:(NSString *) authSig
              tokenSig:(NSString *) tokenSig
            keyVersion:(NSString *) keyversion
          successBlock:(HTTPSuccessBlock) successBlock
          failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"/users/delete" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
    
}


-(void) getPasswordTokenForUsername:(NSString*) username andPassword:(NSString *)password andSignature: (NSString *) signature
                       successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   signature, @"authSig",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"passwordtoken" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
    
    
    
}

-(void) changePasswordForUsername:(NSString *) username
                      oldPassword:(NSString *) password
                      newPassword:(NSString *) newPassword
                          authSig:(NSString *) authSig
                         tokenSig:(NSString *) tokenSig
                       keyVersion:(NSString *) keyversion
                     successBlock:(HTTPSuccessBlock) successBlock
                     failureBlock:(HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   username,@"username",
                                   password,@"password",
                                   authSig, @"authSig",
                                   tokenSig, @"tokenSig",
                                   keyversion, @"keyVersion",
                                   newPassword, @"newPassword",
                                   nil];
    
    
    NSMutableURLRequest *request = [self requestWithMethod:@"PUT" path:@"users/password" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation start];
    
}

-(void) deleteFromCache: (NSURLRequest *) request {
    [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
}




-(void) getShortUrl:(NSString*) longUrl callback: (CallbackBlock) callback
{
    NSString * path = [[NSString stringWithFormat:@"https://api-ssl.bitly.com/v3/shorten?access_token=%@&longUrl=%@", BITLY_TOKEN, longUrl] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" path:nil parameters: nil];
    [request setURL:  [NSURL URLWithString:path]];
    
    
    AFJSONRequestOperation* operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        callback([JSON valueForKeyPath:@"data.url"]);
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        callback(longUrl);
    }];
    [operation start];
}

-(void) addPurchaseReceiptToParams: (NSMutableDictionary *) params {
    NSString * purchaseReceipt = nil;
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        purchaseReceipt = [[NSUserDefaults standardUserDefaults] objectForKey:@"appStoreReceipt"];
    } else {
        purchaseReceipt =  [[NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL] ] base64EncodedStringWithOptions:0];
    }
    
    if (purchaseReceipt) {
        [params setObject: purchaseReceipt forKey:@"purchaseReceipt"];
    }
}
-(void) uploadReceipt: (NSString *) receipt
         successBlock:(HTTPSuccessBlock) successBlock
         failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary * params = [NSMutableDictionary new];
    [self addPurchaseReceiptToParams: params];
    
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"updatePurchaseTokens" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) assignFriendAlias:(NSString *) data friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   data, @"data",
                                   iv,@"iv",
                                   version,@"version",
                                   nil];
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"PUT" path:path  parameters:params];
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) deleteFriendAlias:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/alias", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) deleteFriendImage:(NSString *) friendname successBlock:(HTTPSuccessBlock)successBlock failureBlock: (HTTPFailureBlock) failureBlock {
    
    NSString * path = [[NSString stringWithFormat:@"users/%@/image", friendname] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURLRequest *request = [self requestWithMethod:@"DELETE" path:path  parameters:nil];
    
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request ];
    [operation setCompletionBlockWithSuccess:successBlock failure:failureBlock];
    [operation start];
}

-(void) updateSigs: (NSDictionary *) sigs {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sigs options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    
    NSDictionary * params = [NSDictionary dictionaryWithObjectsAndKeys:jsonString, @"sigs", nil];
    NSMutableURLRequest *request = [self requestWithMethod:@"POST" path:@"sigs" parameters: params];
    AFHTTPRequestOperation * operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [operation start];
}

@end
