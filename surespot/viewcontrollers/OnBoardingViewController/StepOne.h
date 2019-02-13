//
//  StepOne.h
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StepOne : UIView

@property (weak, nonatomic) IBOutlet UIView *circleView;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageViewCenterXConstraint;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *firstContent;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *firstContentCenterXConstraint;
@property (strong, nonatomic) IBOutlet UILabel *secondContent;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *secondContnetCenterXConstraint;

-(void) startAnimation;
-(void) readyAnimation;

@end
