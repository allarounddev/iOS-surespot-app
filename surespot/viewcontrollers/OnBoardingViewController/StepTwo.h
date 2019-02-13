//
//  StepTwo.h
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface StepTwo : UIView

@property (weak, nonatomic) IBOutlet UIView *circleView;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *contentLabel;

-(void) startAnimation;
-(void) readyAnimation;

@end
