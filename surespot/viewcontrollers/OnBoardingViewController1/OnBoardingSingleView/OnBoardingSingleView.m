//
//  OnBoardingPagingScrollView.m
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "OnBoardingSingleView.h"

@interface OnBoardingSingleView()

@property (nonatomic, strong) OnBoardingSingleViewDataModel *onBoardingSingleViewDataModel;

@end

@implementation OnBoardingSingleView

- (id)initOnBoardingSingleViewWithFrame:(CGRect)frame
{
    NSArray *nibViews = [[NSBundle mainBundle] loadNibNamed:@"OnBoardingSingleView" owner:self options:nil];
    self = [nibViews objectAtIndex:0];
    if(self) {
        [self setFrame:frame];
        [self layoutSubviews];
        [self layoutIfNeeded];
    }
    return self;
}

- (void)configureForOnBoardingSingleViewDataModel:(OnBoardingSingleViewDataModel *)onBoardingSingleViewDataModel
{
    _onBoardingSingleViewDataModel = onBoardingSingleViewDataModel;
    [self configureView];
}

- (void)configureView
{
    _descriptionLogoImageView.image = [UIImage imageNamed:_onBoardingSingleViewDataModel.descriptionLogoImageName];
    _descriptionTitleLabel.text = _onBoardingSingleViewDataModel.onBoardingSingleViewDescriptionTitle;
    _descriptionLabel.text = _onBoardingSingleViewDataModel.onBoardingSingleViewDescription;
    [_descriptionLabel sizeToFit];
    [_descriptionLabel layoutIfNeeded];
    [_descriptionLabel layoutSubviews];
    
    if(_onBoardingSingleViewDataModel.actionViewColor) {
        [_actionButtonView setBackgroundColor:_onBoardingSingleViewDataModel.actionViewColor];
    } else {
        [_actionButtonView setBackgroundColor:[UIColor blackColor]];
    }
    _actionNameLabel.text = _onBoardingSingleViewDataModel.actionName;
}

#pragma mark - action
- (IBAction)actionButtonPressed:(id)sender
{
    
}
@end
