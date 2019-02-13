//
//  Friend.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Friend : NSObject<NSCoding>
- (id) initWithDictionary:(NSDictionary *) dictionary;
@property (atomic,strong) NSString * name;
@property (atomic,assign) NSInteger flags;
@property (atomic, strong) NSString * imageUrl;
@property (atomic, strong) NSString * imageVersion;
@property (atomic, strong) NSString * imageIv;
@property (atomic, strong) NSString * aliasPlain;
@property (atomic, strong) NSString * aliasData;
@property (atomic, strong) NSString * aliasVersion;
@property (atomic, strong) NSString * aliasIv;
@property (atomic, assign) NSInteger lastReceivedMessageId;
@property (atomic, assign) NSInteger availableMessageId;
@property (atomic, assign) NSInteger availableMessageControlId;
@property  ( getter = hasNewMessages, setter = setNewMessages:) BOOL hasNewMessages ;

-(void) setFriend;

-(BOOL) isInviter;
-(void) setInviter: (BOOL) set;
-(BOOL) isInvited;
-(void) setInvited: (BOOL) set;

-(BOOL) isDeleted;
-(void) setDeleted;
-(BOOL) isChatActive;
-(void) setChatActive: (BOOL) set;

-(BOOL) isFriend;

-(BOOL) hasFriendImageAssigned;
-(BOOL) hasFriendAliasAssigned;
-(NSString *) nameOrAlias;
-(void) decryptAlias;



@end
