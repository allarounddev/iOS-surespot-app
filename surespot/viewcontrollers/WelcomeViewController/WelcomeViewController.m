//
//  WelcomeViewController.m
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "WelcomeViewController.h"

@interface WelcomeViewController ()

@end

@implementation WelcomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self performSegueWithIdentifier:@"openOnBoardingVIewFromWelcomeView" sender:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.navigationController.navigationBarHidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - action
- (IBAction)infoButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"openOnBoardingVIewFromWelcomeView" sender:self];
}

- (IBAction)getStartedButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"openSignUpViewFromWelcomeView" sender:nil];
}

- (IBAction)signInButtonPressed:(id)sender
{
    [self performSegueWithIdentifier:@"openSignInNewViewFromWelcomeView" sender:nil];
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
