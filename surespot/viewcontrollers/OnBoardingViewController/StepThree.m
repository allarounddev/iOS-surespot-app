//
//  StepThree.m
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "StepThree.h"

@implementation StepThree

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
    
    self.imageView.alpha = 0.0;
    self.titleLabel.alpha = 0.0;
    self.contentLabel.alpha = 0.0;
}

-(void) startAnimation {
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.imageView.alpha = 1.0;
    }completion:nil];
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.titleLabel.alpha = 1.0;
    }completion:nil];
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.contentLabel.alpha = 1.0;
    }completion:nil];
}

@end
