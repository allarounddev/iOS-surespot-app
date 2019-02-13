//
//  HomeDataSource.h
//  surespot
//
//  Created by Adam on 11/2/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Friend.h"

@interface HomeDataSource : NSObject

@property (strong, atomic) NSMutableArray *friends;
@property (atomic, assign) NSInteger latestUserControlId;

- (void) addFriendInvited: (NSString *) name;
- (void) addFriendInviter: (NSString *) name;
- (void) setFriend: (NSString *) username;
- (void) removeFriend: (Friend *) afriend withRefresh: (BOOL) refresh;
-(Friend *) getFriendByName: (NSString *) name;
-(void) postRefresh;
-(void) setAvailableMessageId: (NSInteger) availableId forFriendname: (NSString *) friendname suppressNew: (BOOL) suppressNew;
-(void) setAvailableMessageControlId: (NSInteger) availableId forFriendname: (NSString *) friendname;
-(void) writeToDisk ;
-(void) loadFriendsCallback: (void(^)(BOOL success)) callback;
-(BOOL) hasAnyNewMessages;
-(void) setFriendImageUrl: (NSString *) url forFriendname: (NSString *) name version: version iv: iv;
-(void) setCurrentChat: (NSString *) username;
-(NSString *) getCurrentChat;
-(void) setFriendAlias: (NSString *) alias data: (NSString *) data  friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv;
-(void) removeFriendAlias: (NSString *) friendname;
-(void) removeFriendImage: (NSString *) friendname;
@end
