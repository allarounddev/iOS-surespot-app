//
//  StepOne.m
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "StepOne.h"

@implementation StepOne

-(id) init {
    return [super init];
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    return [super initWithCoder:aDecoder];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _circleView.layer.cornerRadius = _circleView.frame.size.height / 2;
}

-(void) readyAnimation {
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;

    _imageViewCenterXConstraint.constant = - (self.imageView.frame.size.width);
    _firstContentCenterXConstraint.constant = screenSize.width / 2;
    _secondContnetCenterXConstraint.constant = screenSize.width / 2;
    
//    self.imageView.frame = CGRectMake(-(self.imageView.frame.size.width), self.imageView.frame.origin.y, self.imageView.frame.size.width, self.imageView.frame.size.height);
//    self.titleLabel.frame = CGRectMake(screenSize.width, self.titleLabel.frame.origin.y, self.titleLabel.frame.size.width, self.titleLabel.frame.size.height);
//    self.firstContent.frame = CGRectMake(screenSize.width, self.firstContent.frame.origin.y, self.firstContent.frame.size.width, self.firstContent.frame.size.height);
//    self.secondContent.frame = CGRectMake(screenSize.width, self.secondContent.frame.origin.y, self.secondContent.frame.size.width, self.secondContent.frame.size.height);
    
    self.imageView.hidden = true;
    self.titleLabel.hidden = true;
    self.firstContent.hidden = true;
    self.secondContent.hidden = true;
}

-(void) startAnimation {
    
    self.imageView.hidden = false;
    self.titleLabel.hidden = false;
    self.firstContent.hidden = false;
    self.secondContent.hidden = false;
    
//    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    _imageViewCenterXConstraint.constant = 0;
    _firstContentCenterXConstraint.constant = 0;
    _secondContnetCenterXConstraint.constant = 0;
    
    __weak StepOne *weakSelf = self;
    [UIView animateWithDuration:0.3 animations:^{
        [weakSelf layoutIfNeeded];
    } completion:^(BOOL finished) {
        
    }];
    
    
//    [UIView animateWithDuration:0.3f animations:^{
//        CGSize size = self.imageView.frame.size;
//        CGPoint origin = self.imageView.frame.origin;
//        self.imageView.frame = CGRectMake((screenSize.width / 2 - size.width / 2), origin.y, size.width, size.height);
//    }];
//    
//    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
//        CGSize size = self.titleLabel.frame.size;
//        CGPoint origin = self.titleLabel.frame.origin;
//        self.titleLabel.frame = CGRectMake((screenSize.width / 2 - size.width / 2), origin.y, size.width, size.height);
//    }completion:nil];
//    
//    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
//        CGSize size = self.firstContent.frame.size;
//        CGPoint origin = self.firstContent.frame.origin;
//        self.firstContent.frame = CGRectMake((screenSize.width / 2 - size.width / 2), origin.y, size.width, size.height);
//    }completion:nil];
//    
//    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
//        CGSize size = self.secondContent.frame.size;
//        CGPoint origin = self.secondContent.frame.origin;
//        self.secondContent.frame = CGRectMake((screenSize.width / 2 - size.width / 2), origin.y, size.width, size.height);
//    }completion:nil];
}

@end
