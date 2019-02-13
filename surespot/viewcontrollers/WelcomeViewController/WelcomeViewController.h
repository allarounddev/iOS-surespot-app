//
//  WelcomeViewController.h
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WelcomeViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIButton *getStartedButton;
@property (weak, nonatomic) IBOutlet UIButton *signInButton;

- (IBAction)infoButtonPressed:(id)sender;
- (IBAction)getStartedButtonPressed:(id)sender;
- (IBAction)signInButtonPressed:(id)sender;

@end
