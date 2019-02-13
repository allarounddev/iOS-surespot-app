//
//  PageControl.m
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "PageControl.h"

@implementation PageControl

-(id) init {
    _baseTag = 1001;
    _currentIndex = 0;
    return [super init];
}

-(id) initWithCoder:(NSCoder *)aDecoder {
    _baseTag = 1001;
    _currentIndex = 0;
    
    return [super initWithCoder:aDecoder];
}

- (void)setIndex:(NSInteger) index {
    _currentIndex = index;
    
    UIView* indicator = [self viewWithTag:_currentIndex + _baseTag];
    CGPoint center = CGPointMake(indicator.frame.origin.x + indicator.frame.size.width / 2, indicator.frame.origin.y + indicator.frame.size.height / 2);
    [self.selectIndicator setFrame:CGRectMake(center.x - _selectIndicator.frame.size.width / 2, center.y - _selectIndicator.frame.size.height / 2, _selectIndicator.frame.size.width, _selectIndicator.frame.size.height)];
}

-(void) pageAnimation {
    UIView* newIndicator = [self viewWithTag:_currentIndex + _baseTag];
    CGPoint center = CGPointMake(newIndicator.frame.origin.x + newIndicator.frame.size.width / 2, newIndicator.frame.origin.y + newIndicator.frame.size.height / 2);
    
    _selectedIndicatorLeftConstraint.constant = center.x - self.selectIndicator.frame.size.width / 2;
    __weak PageControl *weakSelf = self;
    [UIView animateWithDuration:0.3 animations:^{
        [weakSelf layoutIfNeeded];
    } completion:^(BOOL finished) {
        
    }];
    
//    [UIView animateWithDuration:0.3f animations:^{
//        self.selectIndicator.frame = CGRectMake(center.x - self.selectIndicator.frame.size.width / 2, center.y - self.selectIndicator.frame.size.height / 2, self.selectIndicator.frame.size.width, self.selectIndicator.frame.size.height);
//    }];
}

-(void) goNext {
    _currentIndex = (_currentIndex + 1) % 3;
    [self pageAnimation];
}

-(void) goPrevious {
    _currentIndex = (_currentIndex - 1) % 3;
    [self pageAnimation];
}

-(void) setIndexWithAnimation:(NSInteger) index {
    _currentIndex = index;
    [self pageAnimation];
}


@end
