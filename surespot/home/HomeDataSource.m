//
//  HomeDataSource.m
//  surespot
//
//  Created by Adam on 11/2/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "HomeDataSource.h"
#import "NetworkController.h"
#import "FileController.h"
#import "DDLog.h"
#import "SDWebImageManager.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_OFF;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface  HomeDataSource()
@property (strong, atomic) NSString * cChat;
@end

@implementation HomeDataSource
-(HomeDataSource*)init {
    self = [super init];
    
    if (self != nil) {
        //if we have data on file, load it
        //otherwise load from network
        NSString * path =[FileController getHomeFilename];
        DDLogVerbose(@"looking for home data at: %@", path);
        id homeData = nil;
        @try {
            homeData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        }
        @catch (NSException * e) {
            
        }
        if (homeData) {
            DDLogVerbose(@"loading home data from: %@", path);
            _latestUserControlId = [[homeData objectForKey:@"userControlId"] integerValue];
            _friends = [homeData objectForKey:@"friends"];
        }
        
        if (!_friends) {
            _friends = [NSMutableArray new];
        }
    }
    
    DDLogVerbose(@"HomeDataSource init, latestUserControlId: %d", _latestUserControlId);
    return self;
}

-(void) loadFriendsCallback: (void(^)(BOOL success)) callback{
    DDLogInfo(@"startProgress");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object:nil];
    
    [[NetworkController sharedInstance] getFriendsSuccessBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        DDLogInfo(@"get friends response: %d",  [response statusCode]);
        
        _latestUserControlId = [[JSON objectForKey:@"userControlId"] integerValue];
        
        NSArray * friendDicts = [JSON objectForKey:@"friends"];
        for (NSDictionary * friendDict in friendDicts) {
            [_friends addObject:[[Friend alloc] initWithDictionary: friendDict]];
        };
        [self writeToDisk];
        [self postRefresh];
        callback(YES);
        DDLogInfo(@"stopProgress");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object:nil];
        
    } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
        DDLogInfo(@"response failure: %@",  Error);
        [self postRefresh];
        callback(NO);
        DDLogInfo(@"stopProgress");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object:nil];
        
    }];
    
}

- (void) setFriend: (NSString *) username  {
    Friend * theFriend = [self getFriendByName:username];
    if (!theFriend) {
        theFriend = [self addFriend:username];
    }
    
    [theFriend setFriend];
    [self postRefresh];
}

- (Friend *) addFriend: (NSString *) name {
    Friend *    theFriend = [Friend new];
    theFriend.name =name;
    @synchronized (_friends) {
        [_friends addObject:theFriend];
    }
    return theFriend;
}

- (void)addFriendInvited:(NSString *) username
{
    DDLogVerbose(@"entered");
    Friend * theFriend = [self getFriendByName:username];
    if (!theFriend) {
        theFriend = [self addFriend:username];
        
    }
    
    [theFriend setInvited:YES];
    [self postRefresh];
}

- (void)addFriendInviter:(NSString *) username
{
    DDLogVerbose(@"entered");
    Friend * theFriend = [self getFriendByName:username];
    
    if (!theFriend) {
        theFriend = [self addFriend:username];
    }
    
    [theFriend setInviter:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"invite" object:theFriend];
    });
    [self postRefresh];
    
}

- (void) removeFriend: (Friend *) afriend withRefresh: (BOOL) refresh {
    DDLogInfo(@"name: %@", afriend.name);
    @synchronized (_friends) {
        [_friends removeObject:afriend];
    }
    if (refresh) {
        [self postRefresh];
    }
}

-(void) postRefresh {
    [self sort];
    [self writeToDisk];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshHome" object:nil];
    });
}

-(Friend *) getFriendByName: (NSString *) name {
    @synchronized (_friends) {
        for (Friend * afriend in _friends) {
            if ([[afriend name] isEqualToString:name]) {
                return  afriend;
            }
        }
    }
    
    return nil;
}

-(void) setAvailableMessageId: (NSInteger) availableId forFriendname: (NSString *) friendname suppressNew: (BOOL) suppressNew {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        afriend.availableMessageId = availableId;
        if (suppressNew) {
            afriend.lastReceivedMessageId = availableId;
        }
        if (afriend.availableMessageId > afriend.lastReceivedMessageId) {
            afriend.hasNewMessages = YES;
        }
    }
}

-(void) setAvailableMessageControlId: (NSInteger) availableId forFriendname: (NSString *) friendname {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        afriend.availableMessageControlId = availableId;
    }
}

-(void) writeToDisk {
    @synchronized (_friends) {
        if (_latestUserControlId > 0 || _friends.count > 0) {
            NSString * filename =[FileController getHomeFilename];
            DDLogVerbose(@"saving home data to disk at %@, latestUserControlId: %d, currentChat: %@",filename, _latestUserControlId, [self getCurrentChat]);
            NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
            if (_friends.count > 0) {
                [dict setObject:_friends  forKey:@"friends"];
            }
            if (_latestUserControlId > 0) {
                [dict setObject:[NSNumber numberWithInteger: _latestUserControlId] forKey:@"userControlId"];
            }
            if ([self getCurrentChat]) {
                [dict setObject:[self getCurrentChat] forKey:@"currentChat"];
            }
            BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
            DDLogVerbose(@"save success?: %@",saved ? @"YES" : @"NO");
        }
    }
}

-(void) setCurrentChat: (NSString *) username {
    @synchronized (self) {
        if (username) {
            Friend * afriend = [self getFriendByName:username];
            [afriend setChatActive:YES];
            afriend.lastReceivedMessageId = afriend.availableMessageId;
            afriend.hasNewMessages = NO;
            [self postRefresh];
        }
        
        DDLogInfo(@"setCurrentChat: %@", username);
        self.cChat = username;
    }
}

-(NSString *) getCurrentChat {
    
    NSString * theCurrentChat;
    @synchronized (self) {
        theCurrentChat = _cChat;
    }
    
    DDLogInfo(@"currentChat: %@", theCurrentChat);
    return theCurrentChat;
    
}

-(void) sort {
    @synchronized (_friends) {
        DDLogInfo(@"sorting friends");
        _friends = [NSMutableArray  arrayWithArray:[_friends sortedArrayUsingSelector:@selector(compare:)]];
    }
}

-(BOOL) hasAnyNewMessages {
    @synchronized (_friends) {
        
        for (Friend * afriend in _friends) {
            if (afriend.hasNewMessages ) {
                return YES;
            }
        }
    }
    
    return NO;
    
    
}

-(void) setFriendImageUrl: (NSString *) url forFriendname: (NSString *) name version: version iv: iv {
    Friend * afriend = [self getFriendByName:name];
    if (afriend) {
        NSString * oldUrl = [afriend imageUrl];
        if (oldUrl) {
            [[[SDWebImageManager sharedManager] imageCache] removeImageForKey:oldUrl fromDisk:YES];
        }
        
        [afriend setImageUrl:url];
        [afriend setImageVersion:version];
        [afriend setImageIv:iv];
        
        [self writeToDisk];
        [self postRefresh];
    }
}

-(void) setFriendAlias: (NSString *) alias data: (NSString *) data  friendname: (NSString *) friendname version: (NSString *) version iv: (NSString *) iv {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        [afriend setAliasData:data];
        [afriend setAliasVersion:version];
        [afriend setAliasIv:iv];
        
        //assign plain
        if (alias) {
            [afriend setAliasPlain: alias];
        }
        else {
            [afriend decryptAlias];
        }
        
        [self writeToDisk];
        [self postRefresh];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadSwipeView" object: nil];
    }
}

-(void) removeFriendAlias: (NSString *) friendname {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        [afriend setAliasData:nil];
        [afriend setAliasVersion:nil];
        [afriend setAliasIv:nil];
        
        [afriend setAliasPlain: nil];
        
        [self writeToDisk];
        [self postRefresh];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadSwipeView" object: nil];
    }
}

-(void) removeFriendImage: (NSString *) friendname {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        NSString * oldUrl = [afriend imageUrl];
        if (oldUrl) {
            [[[SDWebImageManager sharedManager] imageCache] removeImageForKey:oldUrl fromDisk:YES];
        }
        
        [afriend setImageUrl:nil];
        [afriend setImageVersion:nil];
        [afriend setImageIv:nil];
        
        [self writeToDisk];
        [self postRefresh];
    }
}

@end
