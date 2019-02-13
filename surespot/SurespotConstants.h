//
//  SurespotConstants.h
//  surespot
//
//  Created by Adam on 11/18/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CallbackBlock) (id  result);
typedef void (^CallbackErrorBlock) (NSString * error, id  result);
typedef void (^CallbackStringBlock) (NSString * result);
typedef void (^CallbackDictionaryBlock) (NSDictionary * result);

@interface SurespotConstants : NSObject
extern NSString * const serverBaseIPAddress;
extern BOOL const serverSecure;
extern NSInteger const serverPort;
extern NSString * const serverPublicKeyString;
extern NSInteger const SAVE_MESSAGE_COUNT;
extern NSString * const MIME_TYPE_IMAGE;
extern NSString * const MIME_TYPE_TEXT;
extern NSString * const MIME_TYPE_M4A;
extern NSInteger const MAX_IDENTITIES;

extern NSString * const FACEBOOK_APP_ID;

extern NSString * const TUMBLR_CONSUMER_KEY;
extern NSString * const TUMBLR_SECRET;
extern NSString * const TUMBLR_CALLBACK_URL;


extern NSString *const GOOGLE_CLIENT_ID;
extern NSString *const GOOGLE_CLIENT_SECRET;

extern NSString * const BITLY_TOKEN;



@end
