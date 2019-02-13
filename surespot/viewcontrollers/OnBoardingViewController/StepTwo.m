//
//  StepTwo.m
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "StepTwo.h"

@implementation StepTwo

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
    
    self.imageView.transform = CGAffineTransformMakeScale(0.0, 0.0);
    self.titleLabel.transform = CGAffineTransformMakeScale(0.0, 0.0);
    self.contentLabel.transform = CGAffineTransformMakeScale(0.0, 0.0);
}

-(void) startAnimation {
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.imageView.transform = CGAffineTransformIdentity;
    }completion:nil];
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.titleLabel.transform = CGAffineTransformIdentity;
    }completion:nil];
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.contentLabel.transform = CGAffineTransformIdentity;
    }completion:nil];
}

@end
