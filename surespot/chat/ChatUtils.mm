//
//  ChatUtils.m
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "ChatUtils.h"
#import "IdentityController.h"

@implementation ChatUtils

+ (NSString *) getSpotUserA: (NSString *) userA userB: (NSString *) userB {
    NSComparisonResult res = [userA compare: userB];
    switch (res ) {
        case NSOrderedAscending:
        case NSOrderedSame:
            return [NSString stringWithFormat:@"%@:%@", userA, userB];
            
        case NSOrderedDescending:
            return [NSString stringWithFormat:@"%@:%@", userB, userA];
            break;
    }    
}

+ (NSString *)  getOtherUserWithFrom: (NSString *) from andTo: (NSString *) to {
    return [to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser] ] ? from : to;
}
+ (NSString *) getOtherUserFromSpot: (NSString *) spot andUser: (NSString *) user {
    NSArray * split = [spot componentsSeparatedByString:@":"];
    return [split[0] isEqualToString:user] ? split[1] : split[0];
}
+ (BOOL) isOurMessage: (SurespotMessage *) message {
    return  [[message from] isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]];
}

+ (NSString *) hexFromData: (NSData *) data {
    NSUInteger dataLength = [data length];
    NSMutableString *string = [NSMutableString stringWithCapacity:dataLength*2];
    const unsigned char *dataBytes = (unsigned char *)[data bytes];
    for (NSInteger idx = 0; idx < dataLength; ++idx) {
        [string appendFormat:@"%02x", dataBytes[idx]];
    }
    return string;
}

+(NSData *)dataFromHex:(NSString *)hex
{
	char buf[3];
	buf[2] = '\0';
	NSAssert(0 == [hex length] % 2, @"Hex strings should have an even number of digits (%@)", hex);
	unsigned char *bytes = (unsigned char *) malloc([hex length]/2);
	unsigned char *bp = bytes;
	for (CFIndex i = 0; i < [hex length]; i += 2) {
		buf[0] = [hex characterAtIndex:i];
		buf[1] = [hex characterAtIndex:i+1];
		char *b2 = NULL;
		*bp++ = strtol(buf, &b2, 16);
		NSAssert(b2 == buf + 2, @"String should be all hex digits: %@ (bad digit around %ld)", hex, i);
	}
	
	return [NSData dataWithBytesNoCopy:bytes length:[hex length]/2 freeWhenDone:YES];
}

@end
