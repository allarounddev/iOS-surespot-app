//
//  OnboardingController.h
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PageControl.h"
#import "StepOne.h"
#import "StepTwo.h"
#import "StepThree.h"

@interface OnboardingController : UIViewController <UIScrollViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIView *buttonBackground;
@property (strong, nonatomic) IBOutlet UIButton *nextButton;

@property (strong, nonatomic) PageControl* pageControl;
@property (strong, nonatomic) StepOne* stepOne;
@property (strong, nonatomic) StepTwo* stepTwo;
@property (strong, nonatomic) StepThree* stepThree;
@property (strong, nonatomic) StepOne* restepOne;
@property (strong, nonatomic) StepThree* restepThree;

@property (nonatomic) NSInteger pageIndex;

- (IBAction)closeButtonPressed:(id)sender;
- (IBAction)onClickNext:(id)sender;

@end
