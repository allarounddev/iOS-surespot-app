//
//  KeyFingerprintViewController.h
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UsernameAliasMap.h"

@interface KeyFingerprintViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
-(id) initWithNibName:(NSString *)nibNameOrNil username: (UsernameAliasMap *) username;
@end
