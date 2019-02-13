//
//  RestoreIdentitiesViewController.m
//  surespot
//
//  Created by Adam on 3/17/14.
//  Copyright (c) 2014 surespot. All rights reserved.
//

#import "RestoreIdentitiesViewController.h"
#import "RestoreIdentityDriveViewController.h"
#import "RestoreIdentityDocumentsViewController.h"

@interface RestoreIdentitiesViewController ()

@end

@implementation RestoreIdentitiesViewController

- (id)init
{
    self = [super init];
    if (self) {
        
        RestoreIdentityDriveViewController * drivecontroller = [[RestoreIdentityDriveViewController alloc] initWithNibName:@"RestoreIdentityDriveView" bundle:[NSBundle mainBundle]];
        drivecontroller.tabBarItem.title = NSLocalizedString(@"google_drive", nil);
        [drivecontroller.tabBarItem setImage:[UIImage imageNamed:@"drive"]];
        RestoreIdentityDocumentsViewController * documentscontroller = [[RestoreIdentityDocumentsViewController alloc] initWithNibName:@"RestoreIdentityDocumentsView" bundle:[NSBundle mainBundle]];
        documentscontroller.tabBarItem.title = NSLocalizedString(@"documents", nil);
        [documentscontroller.tabBarItem setImage:[UIImage imageNamed:@"ic_menu_archive"]];
        
        [self setViewControllers: @[documentscontroller,drivecontroller]];
        [self.navigationItem setTitle:NSLocalizedString(@"restore", nil)];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
