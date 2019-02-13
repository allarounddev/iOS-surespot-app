//
//  OnBoardingViewController.m
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "OnBoardingViewController.h"
#import "OnBoardingSingleViewDataModel.h"

@interface OnBoardingViewController () <PagingScrollViewDelegate>

@end

@implementation OnBoardingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self configureOnBoardinPaginScrollView];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureOnBoardinPaginScrollView
{
    _onBoardinPaginScrollView.pagingScrollViewDelegate = self;
    
    NSMutableArray *onBoardingViewDataModelsArray = [[NSMutableArray alloc] init];
    
    OnBoardingSingleViewDataModel *onBoardingFirstViewDataModel = [[OnBoardingSingleViewDataModel alloc] init];
    onBoardingFirstViewDataModel.descriptionLogoImageName = @"On-BoardingStep1Logo";
    onBoardingFirstViewDataModel.onBoardingSingleViewDescriptionTitle = @"YOUR IN CONTROL";
    onBoardingFirstViewDataModel.onBoardingSingleViewDescription = @"All the information is in your hands\n - even after it has left your hands. Delete messages from the receivers device at your convenience if you no longer want it out there.";
    onBoardingFirstViewDataModel.actionViewColor = [UIColor blackColor];
    onBoardingFirstViewDataModel.actionName = @"NEXT";
    
    [onBoardingViewDataModelsArray addObject:onBoardingFirstViewDataModel];
    
    OnBoardingSingleViewDataModel *onBoardingSecongViewDataModel = [[OnBoardingSingleViewDataModel alloc] init];
    onBoardingSecongViewDataModel.descriptionLogoImageName = @"On-BoardingStep2Logo";
    onBoardingSecongViewDataModel.onBoardingSingleViewDescriptionTitle = @"EASY TO USE";
    onBoardingSecongViewDataModel.onBoardingSingleViewDescription = @"Giving you the seamless experience of communicating what you want without hesitation.";
    onBoardingSecongViewDataModel.actionViewColor = [UIColor blackColor];
    onBoardingSecongViewDataModel.actionName = @"NEXT";
    [onBoardingViewDataModelsArray addObject:onBoardingSecongViewDataModel];
    
    OnBoardingSingleViewDataModel *onBoardingThirdViewDataModel = [[OnBoardingSingleViewDataModel alloc] init];
    onBoardingThirdViewDataModel.descriptionLogoImageName = @"On-BoardingStep3Logo";
    onBoardingThirdViewDataModel.onBoardingSingleViewDescriptionTitle = @"NEXT-GENERATION ";
    onBoardingThirdViewDataModel.onBoardingSingleViewDescription = @" Encrypted, private, and anonymous. messaging with support for offline P2P messaging.";
    onBoardingThirdViewDataModel.actionViewColor = [UIColor colorWithRed:0.0/255.0 green:153.0/255.5 blue:255.0/255.0 alpha:1.0];
    onBoardingThirdViewDataModel.actionName = @"GET STARTED";
    [onBoardingViewDataModelsArray addObject:onBoardingThirdViewDataModel];
    
    
    [_onBoardinPaginScrollView configureScrollViewWithViewDataModelsArray:onBoardingViewDataModelsArray];
    
//    [_onBoardinPaginScrollView configureScrollViewWithImages:imageURLsArray andContent:nil];
}

#pragma mark - PagingScrollViewDelegate
- (void)imageDidScrollToPage:(NSInteger)currentPage
{
    
}

- (void)openNextView
{
    [self openWelcomeView];
}

#pragma mark - action
- (void)openWelcomeView
{
    [self performSegueWithIdentifier:@"openWelcomeVIewFromOnBoardView" sender:self];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
