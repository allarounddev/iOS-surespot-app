//
//  PublicKeys.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "PublicKeys.h"


@implementation PublicKeys
-(void) dealloc {
    delete _dhPubKey;
    delete _dsaPubKey;
}
@end
