//
//  RemoveIdentityFromDeviceViewController.m
//  surespot
//
//  Created by Owen Emlen on 8/28/15.
//  Copyright (c) 2015 surespot. All rights reserved.
//


#import "RemoveIdentityFromDeviceViewController.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "FileController.h"
#import "NSData+Gunzip.h"
#import "NSString+Sensitivize.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"

#import "EncryptionController.h"
#import "NetworkController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface RemoveIdentityFromDeviceViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label1;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;
@property (atomic, strong) LoadingView * progressView;
@property (atomic, strong) NSString * name;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * url;
@end



@implementation RemoveIdentityFromDeviceViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"remove", nil)];
    [_bExecute setTitle:NSLocalizedString(@"remove_identity_from_device", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    _label1.text = NSLocalizedString(@"remove_identity_from_device_message_warning", nil);
    
    _scrollView.contentSize = self.view.frame.size;
    if ([[IdentityController sharedInstance] getLoggedInUser]) {
        [_userPicker selectRow:[_identityNames indexOfObject:[[IdentityController sharedInstance] getLoggedInUser]] inComponent:0 animated:YES];
    } else {
        [_userPicker selectRow:(_selectUsername ? [_identityNames indexOfObject:_selectUsername] : 0) inComponent:0 animated:YES];
    }
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}



// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_identityNames count];
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 37)];
    label.text =  [_identityNames objectAtIndex:row];
    [label setFont:[UIFont systemFontOfSize:22]];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (IBAction)execute:(id)sender {
    NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    _name = name;
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"remove_identity_from_device_user", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [alertView show];
    
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString * password = nil;
        if (alertView.alertViewStyle == UIAlertViewStyleSecureTextInput) {
            password = [[alertView textFieldAtIndex:0] text];
        }
        
        if (![UIUtils stringIsNilOrEmpty:password]) {
            [self removeIdentityForUsername:_name password:password];
        }
    }
}

-(void) removeIdentityForUsername: (NSString *) username password: (NSString *) password {
    _progressView = [LoadingView showViewKey:@"remove_identity_from_device_progress"];
    SurespotIdentity * identity = [[IdentityController sharedInstance] loadIdentityUsername:username password:password];
    if (!identity) {
        [_progressView removeView];
        _progressView = nil;
        [UIUtils showToastKey:@"could_not_remove_identity_from_device" duration:3];
        return;
    }
    
    [self loadIdentityNames];
    [[IdentityController sharedInstance] deleteIdentityUsername:username preserveBackedUpIdentity:YES];
    [_progressView removeView];
    _progressView = nil;
    [UIUtils showToastKey:@"identity_removed_from_device" duration:2];
    [self loadIdentityNames];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}


@end
