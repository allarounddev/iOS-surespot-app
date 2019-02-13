//
//  OnBoardingPagingScrollView.h
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OnBoardingSingleViewDataModel.h"

@interface OnBoardingSingleView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *descriptionLogoImageView;
@property (weak, nonatomic) IBOutlet UILabel *descriptionTitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;
@property (weak, nonatomic) IBOutlet UIView *actionButtonView;
@property (weak, nonatomic) IBOutlet UILabel *actionNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *actionButton;

- (id)initOnBoardingSingleViewWithFrame:(CGRect)frame;

- (void)configureForOnBoardingSingleViewDataModel:(OnBoardingSingleViewDataModel*)onBoardingSingleViewDataModel;

- (IBAction)actionButtonPressed:(id)sender;

@end
