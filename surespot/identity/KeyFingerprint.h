//
//  KeyFingerprint.h
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyFingerprint : NSObject<UICollectionViewDataSource>
-(id) initWithFingerprintData: (NSString *) hexData forTitle: (NSString *) title;
@end
