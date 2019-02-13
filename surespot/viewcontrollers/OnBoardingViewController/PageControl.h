//
//  PageControl.h
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PageControl : UIView


@property (strong, nonatomic) IBOutlet UIView *selectIndicator;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *selectedIndicatorLeftConstraint;

@property (nonatomic) NSInteger currentIndex;
@property (nonatomic) NSInteger baseTag;

-(void) setIndex:(NSInteger) index;
-(void) pageAnimation;
-(void) goNext;
-(void) goPrevious;
-(void) setIndexWithAnimation:(NSInteger) index;

@end
