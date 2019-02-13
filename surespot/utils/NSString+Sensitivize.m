//
//  NSString+Sensitivize.m
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "NSString+Sensitivize.h"
#import "ChatUtils.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@implementation NSString (Sensitivize)


-(NSString *) hexEncode {
    NSString  * s = [@"1-" stringByAppendingString:[ChatUtils hexFromData:[self dataUsingEncoding:NSUTF8StringEncoding]]];
    return s;
}

-(NSString *) hexDecode: (NSString *) string {
    NSString * s = [[NSString alloc] initWithData:[ChatUtils dataFromHex:string] encoding:NSUTF8StringEncoding];
    return s;
    
    
}

-(NSString *) caseInsensitivize {
    NSMutableString * sb = [NSMutableString new];
    [self enumerateSubstringsInRange:NSMakeRange(0,[self length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                              DDLogVerbose(@"char: %@", substring);
                              unichar buffer[1];
                              
                              [self getCharacters:buffer range:substringRange];
                              
                              if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:buffer[0]]) {
                                  
                                  [sb appendString:@"_"];
                              }
                              [sb appendString: substring];
                          }];
    NSString * s = [NSString stringWithString:sb];
    return s;
}

-(NSString *) oldCaseInsensitivize {
    NSMutableString * sb = [NSMutableString new];

    for (int i = 0; i < [self length]; i++) {
        unichar uni = [self characterAtIndex:i];

        if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:uni]) {
            [sb appendString:@"_"];
            [sb appendFormat:@"%c",[self characterAtIndex:i]];
        }
        else {
            [sb appendFormat:@"%c",uni];
        }
    }
    return sb;
}

-(NSString *) caseSensitivize {
    __block BOOL prev_ = NO;
    
    //this is key to not having jacked up characters
    //NSString uses compacted UTF-8 which doesn't play well with others
    NSString * cs = [self precomposedStringWithCompatibilityMapping];    
    
    NSMutableString * sb = [NSMutableString new];
    [cs enumerateSubstringsInRange:NSMakeRange(0,[cs length])
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock: ^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                              DDLogVerbose(@"char: %@", substring);
                              
                              if (prev_) {
                                  [sb appendString:[substring uppercaseString]];
                                  prev_ = NO;
                              }
                              else {
                                  
                                  if ([substring isEqualToString: @"_"]) {
                                      prev_ = YES;
                                  }
                                  else {
                                      [sb appendString: substring];
                                  }
                              }}];
    
    return sb;
}

@end
