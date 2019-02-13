
//
//  OnboardingController.m
//  surespot
//
//  Created by PSIHPOK on 7/17/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "OnboardingController.h"
#import "SurespotAppDelegate.h"
/*
#import "SurespotMessage.h"
#import "ChatController.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "SurespotLogFormatter.h"
#import "UIUtils.h"
#import "IdentityController.h"
#import "UIUtils.h"
#import "AGWindowView.h"
#import <StoreKit/StoreKit.h>
#import "PurchaseDelegate.h"
#import "SoundController.h"
#import "CredentialCachingController.h"
#import "FileController.h"
*/
 
@implementation OnboardingController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    _pageIndex = 0;
    [self loadPageControl];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self loadSteps];
    });
}

- (void)loadSteps
{
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    NSArray* nibone = (NSArray*) [[NSBundle mainBundle] loadNibNamed:@"StepOne" owner:self options:nil];
    _stepOne = (StepOne*) nibone[0];
    _stepOne.frame = CGRectMake(screenSize.width, 0, screenSize.width, screenSize.height);
    
    NSArray* nibtwo = (NSArray*) [[NSBundle mainBundle] loadNibNamed:@"StepTwo" owner:self options:nil];
    _stepTwo = (StepTwo*) nibtwo[0];
    _stepTwo.frame = CGRectMake(screenSize.width * 2, 0, screenSize.width, screenSize.height);
    
    NSArray* nibthree = (NSArray*) [[NSBundle mainBundle] loadNibNamed:@"StepThree" owner:self options:nil];
    _stepThree = (StepThree*) nibthree[0];
    _stepThree.frame = CGRectMake(screenSize.width * 3, 0, screenSize.width, screenSize.height);
    
    NSArray* renibone = (NSArray*) [[NSBundle mainBundle] loadNibNamed:@"StepOne" owner:self options:nil];
    _restepOne = (StepOne*) renibone[0];
    _restepOne.frame = CGRectMake(screenSize.width * 4, 0, screenSize.width, screenSize.height);
    
    NSArray* renibthree = (NSArray*) [[NSBundle mainBundle] loadNibNamed:@"StepThree" owner:self options:nil];
    _restepThree = (StepThree*) renibthree[0];
    _restepThree.frame = CGRectMake(0, 0, screenSize.width, screenSize.height);
    
    self.scrollView.contentSize = CGSizeMake(screenSize.width * 5, self.scrollView.frame.size.height);
    
    [self.scrollView addSubview:_restepThree];
    [self.scrollView addSubview:_stepOne];
    [self.scrollView addSubview:_stepTwo];
    [self.scrollView addSubview:_stepThree];
    [self.scrollView addSubview:_restepOne];
    
    [_restepOne readyAnimation];
    [_stepTwo readyAnimation];
    [_stepThree readyAnimation];
    [_restepThree readyAnimation];
    
    self.scrollView.delegate = self;
    _scrollView.bounces = NO;
    
    [self.scrollView scrollRectToVisible:CGRectMake(screenSize.width, 0, screenSize.width, screenSize.height) animated:false];
    
    [_pageControl setIndex:0];
}

- (void)loadPageControl
{
    NSArray* nib = (NSArray*)[[NSBundle mainBundle] loadNibNamed:@"PageControl" owner:self options:nil];
    _pageControl = (PageControl*) nib[0];
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGSize pageControlSize = CGSizeMake(_pageControl.frame.size.width, _pageControl.frame.size.height);
    //CGRect pageControlRect = CGRectMake((screenSize.width - pageControlSize.width) / 2, screenSize.height * 3 / 4, pageControlSize.width, pageControlSize.height);
    CGRect pageControlRect = CGRectMake((screenSize.width - pageControlSize.width) / 2, _buttonBackground.frame.origin.y - pageControlSize.height - 24, pageControlSize.width, pageControlSize.height);
    
    _pageControl.frame = pageControlRect;
    
    [self.view addSubview:_pageControl];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self adjustScrollView];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self adjustScrollView];
}

- (void)adjustScrollView
{
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    NSInteger currentPage = _scrollView.contentOffset.x / screenSize.width;
    
    BOOL bNeedAdjustNextButton = (currentPage - 1 == _pageIndex) ? false : true;
    
    if (currentPage == 0) {
        [_scrollView scrollRectToVisible:CGRectMake(screenSize.width * 3, 0, screenSize.width, screenSize.height) animated: false];
        [_pageControl setIndexWithAnimation:2];
        _pageIndex = 2;
    }
    else if (currentPage == 4) {
        [_scrollView scrollRectToVisible:CGRectMake(screenSize.width, 0, screenSize.width, screenSize.height) animated: false];
        [_pageControl setIndexWithAnimation:0];
        _pageIndex = 0;
    }
    else {
        [_pageControl setIndexWithAnimation:currentPage - 1];
        _pageIndex = currentPage - 1;
    }
    
    if (bNeedAdjustNextButton == true) {
        [self adjustNextButton];
    }
    
    [self adjustAnimation];
}

-(void) adjustAnimation {
    if (_pageIndex == 0) {
        [_stepOne startAnimation];
        [_stepTwo readyAnimation];
        [_stepThree readyAnimation];
        [_restepOne readyAnimation];
        [_restepThree readyAnimation];
    }
    else if (_pageIndex == 1) {
        [_stepOne readyAnimation];
        [_stepTwo startAnimation];
        [_stepThree readyAnimation];
        [_restepOne readyAnimation];
        [_restepThree readyAnimation];
    }
    else {
        [_stepOne readyAnimation];
        [_stepTwo readyAnimation];
        [_stepThree startAnimation];
        [_restepOne readyAnimation];
        [_restepThree readyAnimation];
    }
}

-(void) adjustNextButton {
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    if (_pageIndex == 0 || _pageIndex == 1) {
        [_nextButton setImage:[UIImage imageNamed:@"next.png"] forState:UIControlStateNormal];
        _nextButton.frame = _buttonBackground.frame;
    }
    else {
        _nextButton.frame = CGRectMake(screenSize.width, _nextButton.frame.origin.y, _nextButton.frame.size.width, _nextButton.frame.size.height);
        [_nextButton setImage:[UIImage imageNamed:@"start_btn.png"] forState:UIControlStateNormal];
        [UIView animateWithDuration:0.4f animations:^{
            self.nextButton.frame = self.buttonBackground.frame;
        }];
    }
}

- (IBAction)closeButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:^{
       
    }];
}

- (IBAction)onClickNext:(id)sender
{
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    
    if (_pageControl.currentIndex < 2) {
        CGPoint contentOffset = _scrollView.contentOffset;
        [_scrollView scrollRectToVisible:CGRectMake(contentOffset.x + screenSize.width, 0, screenSize.width, screenSize.height) animated:true];
    }
    else {
        [self goNextScreen];
    }
}

- (void)goNextScreen
{
//    [self performSegueWithIdentifier:@"openWelcomeVIewFromOnBoardView" sender:self];
    [self closeButtonPressed:self.closeButton];
}

@end
