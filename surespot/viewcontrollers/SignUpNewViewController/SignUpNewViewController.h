//
//  SignUpNewViewController.h
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SignUpNewViewController : UIViewController <UIPopoverControllerDelegate>

@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

- (IBAction)actionButtonPressed:(id)sender;

@end
