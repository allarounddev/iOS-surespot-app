//
//  BackupIdentityViewController.h
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BackupIdentityViewController : UIViewController<UIPickerViewDataSource, UIPickerViewDelegate, UIPopoverControllerDelegate>
@property (strong, nonatomic) NSString * selectUsername;
@end
