//
//  Friend.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "Friend.h"
#import "UIUtils.h"
#import "EncryptionController.h"
#import "IdentityController.h"

#define INVITER 32
#define MESSAGE_ACTIVITY 16
#define CHAT_ACTIVE 8
#define NEW_FRIEND 4
#define INVITED 2
#define DELETED 1

@interface  Friend()
@property (nonatomic, assign) BOOL newMessages;
@end

@implementation Friend
- (id) initWithJSONString: (NSString *) jsonString {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    NSDictionary * friendData = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    [self parseDictionary:friendData];
    [self decryptAlias];
    return self;
}

- (id) initWithDictionary:(NSDictionary *) dictionary {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    [self parseDictionary:dictionary];
    [self decryptAlias];
    return self;
}

-(id) initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _name = [coder decodeObjectForKey:@"name"];
        _flags = [coder decodeIntegerForKey:@"flags"];
        _newMessages = [coder decodeBoolForKey:@"hasNewMessages"];
        _availableMessageId = [coder decodeIntegerForKey:@"availableMessageId"];
        _availableMessageControlId =[coder decodeIntegerForKey:@"availableMessageControlId"];
        _lastReceivedMessageId = [coder decodeIntegerForKey:@"lastReceivedMessageId"];
        _imageUrl = [coder decodeObjectForKey:@"imageUrl"];
        _imageIv = [coder decodeObjectForKey:@"imageIv"];
        _imageVersion = [coder decodeObjectForKey:@"imageVersion"];
        _aliasData = [coder decodeObjectForKey:@"aliasData"];
        _aliasIv = [coder decodeObjectForKey:@"aliasIv"];
        _aliasVersion = [coder decodeObjectForKey:@"aliasVersion"];
        [self decryptAlias];
    }
    return self;
}


-(void) parseDictionary:(NSDictionary *) dictionary {
    _name = [dictionary objectForKey:@"name"];
    _flags = [[dictionary  objectForKey:@"flags"] integerValue];
    _imageVersion = [dictionary objectForKey:@"imageVersion"];
    _imageUrl = [dictionary objectForKey:@"imageUrl"];
    _imageIv = [dictionary objectForKey:@"imageIv"];
    _aliasData = [dictionary objectForKey:@"aliasData"];
    _aliasIv = [dictionary objectForKey:@"aliasIv"];
    _aliasVersion = [dictionary objectForKey:@"aliasVersion"];
    
}

-(void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_name forKey:@"name"];
    [encoder encodeInteger:_flags forKey:@"flags"];
    [encoder encodeBool:_newMessages forKey:@"hasNewMessages"];
    [encoder encodeInteger:_availableMessageId forKey:@"availableMessageId"];
    [encoder encodeInteger:_availableMessageControlId forKey:@"availableMessageControlId"];
    [encoder encodeInteger:_lastReceivedMessageId  forKey:@"lastReceivedMessageId"];
    [encoder encodeObject:_imageVersion forKey:@"imageVersion"];
    [encoder encodeObject:_imageUrl forKey:@"imageUrl"];
    [encoder encodeObject:_imageIv forKey:@"imageIv"];
    [encoder encodeObject:_aliasVersion forKey:@"aliasVersion"];
    [encoder encodeObject:_aliasData forKey:@"aliasData"];
    [encoder encodeObject:_aliasIv forKey:@"aliasIv"];
}

-(void) decryptAlias {
    if ([self hasFriendAliasAssigned] && [UIUtils stringIsNilOrEmpty: _aliasPlain]) {
        [EncryptionController symmetricDecryptString:_aliasData ourVersion:_aliasVersion theirUsername:[[IdentityController sharedInstance] getLoggedInUser] theirVersion:_aliasVersion iv:_aliasIv callback:^(id result) {
            _aliasPlain = result;
        }];
        
    }
}

-(void) setFriend {
    //   if (set) {
    //      _flags |= NEW_FRIEND;
    _flags &= ~INVITED;
    _flags &= ~INVITER;
    _flags &= ~DELETED;
    // }
    //    else {
    //        _flags &= ~NEW_FRIEND;
    //    }
    
    
}


-(BOOL) isInviter {
    return (_flags & INVITER) == INVITER;
}

-(void) setInviter: (BOOL) set {
    if (set) {
        _flags |= INVITER;
        _newMessages = NO;
    }
    else {
        _flags &= ~INVITER;
    }
}

-(BOOL) isInvited {
    return (_flags & INVITED) == INVITED;
}

-(void) setInvited: (BOOL) set {
    if (set) {
        _flags |= INVITED;
        _newMessages = NO;
    }
    else {
        _flags &= ~INVITED;
    }
}

-(BOOL) isDeleted {
    return (_flags & DELETED) == DELETED;
}

-(void) setDeleted {
    int active = _flags & CHAT_ACTIVE;
    _newMessages = NO;
    _flags = DELETED | active;
}

-(BOOL) isChatActive {
    return (_flags & CHAT_ACTIVE) == CHAT_ACTIVE;
}

-(void) setChatActive:(BOOL)set {
    if (set) {
        _flags |= CHAT_ACTIVE;
    }
    else {
        _flags &= ~CHAT_ACTIVE;
    }
}


-(BOOL) hasNewMessages {
    if (![self isFriend ] || [self isDeleted]) {
        return NO;
    }
    
    return _newMessages;
}

-(void) setNewMessages: (BOOL) set {
    _newMessages = set;
}

-(BOOL) isFriend {
    return  !self.isInvited && !self.isInviter;
}

-(BOOL) isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[Friend class]])
        return NO;
    
    return [self.name isEqualToString:[other name]];
}


- (NSComparisonResult)compare:(Friend  *)other {
    NSInteger myflags = self.flags;
    
    // for the purposes of sorting we'll add MESSAGE_ACTIVITY to the flags if they have new messages
    if (self.hasNewMessages) {
        myflags |= MESSAGE_ACTIVITY;
    }
    
    myflags &= (CHAT_ACTIVE | MESSAGE_ACTIVITY | INVITER);
    
    NSInteger theirflags = other.flags;
    if (other.hasNewMessages) {
        theirflags |= MESSAGE_ACTIVITY;
    }
    
    theirflags &= (CHAT_ACTIVE | MESSAGE_ACTIVITY | INVITER);
    
    if ((theirflags == myflags) || (theirflags < CHAT_ACTIVE && myflags < CHAT_ACTIVE)) {
        //sort by name
        return [self.nameOrAlias compare:other.nameOrAlias options:NSCaseInsensitiveSearch ];
    }
    else {
        //sort by flag value
        if (theirflags > myflags) return NSOrderedDescending;
        else return NSOrderedAscending;
    }
}



-(BOOL) hasFriendImageAssigned {
    return _imageIv && _imageUrl && _imageVersion;
}

-(BOOL) hasFriendAliasAssigned {
    return _aliasData && _aliasIv && _aliasVersion;
}

-(NSString *) nameOrAlias {
    return [UIUtils stringIsNilOrEmpty:_aliasPlain] ? _name : _aliasPlain;
}


@end
