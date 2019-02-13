//
//  DeleteIdentityFromDeviceViewController.h
//  surespot
//
//  Created by Owen Emlen on 8/28/15.
//  Copyright (c) 2015 surespot. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RemoveIdentityFromDeviceViewController : UIViewController<UIPickerViewDataSource, UIPickerViewDelegate>
@property (strong, nonatomic) NSString * selectUsername;
@end