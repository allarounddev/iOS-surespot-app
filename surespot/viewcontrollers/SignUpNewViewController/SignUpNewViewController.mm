//
//  SignUpNewViewController.m
//  surespot
//
//  Created by Gevorg Karapetyan on 7/16/16.
//  Copyright © 2016 2fours. All rights reserved.
//

#import "SignUpNewViewController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "NetworkController.h"
#import "NSData+Base64.h"
#import "UIUtils.h"
#import "DDLog.h"
#import "LoadingView.h"
#import "RestoreIdentitiesViewController.h"
#import "HelpViewController.h"
#import "SwipeViewController.h"
#import "LoginViewController.h"
#import "BackupIdentityViewController.h"
#import "AboutViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface SignUpNewViewController ()

@property (atomic, strong) id progressView;
@property (nonatomic) BOOL isCheckingUserName;
@property (nonatomic, strong) NSString *lastCheckedUsername;

@property (nonatomic, strong) NSString *userName;
@property (nonatomic, strong) NSString *password;

@end

@implementation SignUpNewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _isCheckingUserName = YES;
    [self configureView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    self.navigationController.navigationBarHidden = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureView
{
    _descriptionLabel.text = @"select a username, you \n would like to use as.";
    [_descriptionLabel sizeToFit];
    [_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self configureAction];
}

- (void)configureAction
{
    if(_isCheckingUserName) {
        [_actionButton setTitle:[NSLocalizedString(@"confirm_username", nil) uppercaseString] forState:UIControlStateNormal];
    } else {
        [_actionButton setTitle:[NSLocalizedString(@"confirm_password", nil) uppercaseString] forState:UIControlStateNormal];
    }
    [_textField resignFirstResponder];
    _textField.text = @"";
}

- (void)createIdentity
{
    NSString * username = _userName;
    NSString * password = _password;
    NSString * confirmPassword = _password;
    
    
    if ([UIUtils stringIsNilOrEmpty:username] || [UIUtils stringIsNilOrEmpty:password] || [UIUtils stringIsNilOrEmpty:confirmPassword]) {
        return;
    }
    
    if (![confirmPassword isEqualToString:password]) {
        [UIUtils showToastKey:@"passwords_do_not_match" duration:1.5];
//        _tbPassword.text = @"";
//        _tbPasswordConfirm.text = @"";
//        [_tbPassword becomeFirstResponder];
        return;
    }
    
    [_textField resignFirstResponder];
//    [_tbPassword resignFirstResponder];
//    [_tbPasswordConfirm resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"create_user_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        
        
        NSDictionary *derived = [EncryptionController deriveKeyFromPassword:password];
        
        NSString * salt = [[derived objectForKey:@"salt" ] SR_stringByBase64Encoding];
        NSString * encPassword = [[derived objectForKey:@"key" ] SR_stringByBase64Encoding];
        
        
        IdentityKeys * keys = [EncryptionController generateKeyPairs];
        
        NSString * encodedDHKey = [EncryptionController encodeDHPublicKey: [keys dhPubKey]];
        NSString * encodedDSAKey = [EncryptionController encodeDSAPublicKey:[keys dsaPubKey]];
        NSString * authSig = [[EncryptionController signUsername:username andPassword: [encPassword dataUsingEncoding:NSUTF8StringEncoding] withPrivateKey:keys.dsaPrivKey] SR_stringByBase64Encoding];
        NSString * clientSig = [[EncryptionController signUsername:username andVersion:1 andDhPubKey:encodedDHKey andDsaPubKey:encodedDSAKey withPrivateKey:keys.dsaPrivKey] SR_stringByBase64Encoding];
        
        [[NetworkController sharedInstance]
         createUser2WithUsername: username
         derivedPassword: encPassword
         dhKey: encodedDHKey
         dsaKey: encodedDSAKey
         authSig: authSig
         clientSig: clientSig
         successBlock:^(AFHTTPRequestOperation *operation, id responseObject, NSHTTPCookie * cookie) {
             DDLogVerbose(@"signup response: %d",  [operation.response statusCode]);
             [[IdentityController sharedInstance] createIdentityWithUsername:username andPassword:password andSalt:salt andKeys:keys cookie:cookie];
             UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
             SwipeViewController * svc = [storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"];
             BackupIdentityViewController * bvc = [[BackupIdentityViewController alloc] initWithNibName:@"BackupIdentityView" bundle:nil];
             bvc.selectUsername = username;
             
             NSMutableArray *  controllers = [NSMutableArray new];
             [controllers addObject:svc];
             [controllers addObject:bvc];
             
             
             //show help view on iphone if it hasn't been shown
             BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
             if ((!tosClicked) && [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
                 HelpViewController *hvc = [[HelpViewController alloc] initWithNibName:@"HelpView" bundle:nil];
                 [controllers addObject:hvc];
             }
             
             self.navigationController.navigationBarHidden = NO;
             [self.navigationController setViewControllers:controllers animated:YES];
             [_progressView removeView];
             _progressView = nil;
         }
         failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
             
             DDLogVerbose(@"signup response failure: %@",  Error);
             
             [_progressView removeView];
             _progressView = nil;
             
             switch (operation.response.statusCode) {
                 case 429:
                     [UIUtils showToastKey: @"user_creation_throttled" duration:3];
                     _isCheckingUserName = YES;
                     [self configureAction];
                     [_textField becomeFirstResponder];
                     break;
                 case 409:
                     [UIUtils showToastKey: @"username_exists" duration:2];
                     _isCheckingUserName = YES;
                     [self configureAction];
                     [_textField becomeFirstResponder];
                     break;
                 case 403:
                     [UIUtils showToastKey: @"signup_update" duration:4];
                     break;
                 default:
                     [UIUtils showToastKey: @"could_not_create_user" duration:2];
             }
             
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         ];
        
    });
    
}


#pragma mark - text field
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if(_isCheckingUserName) {
        [textField resignFirstResponder];
        [self checkUsername];
        return NO;
    } else {
//        if (![UIUtils stringIsNilOrEmpty: textField.text]) {
            [textField resignFirstResponder];
            return NO;
//        }
    }
    
    
    return NO;
}

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if(_isCheckingUserName) {
        
        
        
        NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
        NSString * newString = [string stringByTrimmingCharactersInSet:alphaSet];
        if (![newString isEqualToString:@""]) {
            return NO;
        }
        
        NSUInteger newLength = [textField.text length] + [newString length] - range.length;
        if (newLength == 0) {
//            [_tbUsername setRightViewMode:UITextFieldViewModeNever];
            _lastCheckedUsername = nil;
        }
        return (newLength >= 20) ? NO : YES;
    } else {
        NSUInteger newLength = [textField.text length] + [string length] - range.length;
        return (newLength >= 256) ? NO : YES;
    }
    
    return YES;
}

-(void) checkUsername {
    NSString * username = _userName;
    
    if ([UIUtils stringIsNilOrEmpty:username]) {
        return;
    }
    
    if ([_lastCheckedUsername isEqualToString: username]) {
        return;
    }
    
    _lastCheckedUsername = username;
    _progressView = [LoadingView showViewKey:@"user_exists_progress"];
    
    [[NetworkController sharedInstance] userExists:username successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString * response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        
        [_progressView removeView];
        _progressView = nil;
        
        
        if ([response isEqualToString:@"true"]) {
            [UIUtils showToastKey:@"username_exists"];
            [self setUsernameValidity:NO];
            [_textField becomeFirstResponder];
//            [_tbUsername becomeFirstResponder];
        }
        else {
            [self setUsernameValidity:YES];
            _isCheckingUserName = NO;
            [self configureAction];
            [_textField becomeFirstResponder];
        }
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        _isCheckingUserName = YES;
        [self configureAction];
        [_textField becomeFirstResponder];
        [_progressView removeView];
        _progressView = nil;
        [UIUtils showToastKey:@"user_exists_error"];
        _lastCheckedUsername = nil;
    }];
}


-(void) setUsernameValidity: (BOOL) valid {
    
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
    
    if(_isCheckingUserName) {
        _userName = textField.text;
        [self checkUsername];
    } else {
        _password = textField.text;
    }
}


// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    if ([UIUtils isIOS8Plus]) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardFrameDidChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
        
    }
    else {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];
        
    }
    
    
}


- (void)keyboardFrameDidChange:(NSNotification *)notification
{
//    DDLogInfo(@"keyboardFrameDidChange");
//    CGRect keyboardEndFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
//    CGRect keyboardBeginFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
//    //  UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
//    //  NSTimeInterval animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] integerValue];
//    
//    //  [UIView beginAnimations:nil context:nil];
//    //  [UIView setAnimationDuration:animationDuration];
//    //  [UIView setAnimationCurve:animationCurve];
//    
//    
//    
//    
//    //    CGRect newFrame = _textFieldContainer.frame;
//    CGRect keyboardFrameEnd = [self.view convertRect:keyboardEndFrame toView:nil];
//    
//    
//    CGRect keyboardFrameBegin = [self.view convertRect:keyboardBeginFrame toView:nil];
//    DDLogInfo(@"keyboard frame begin origin y: %f, height: %f", keyboardFrameBegin.origin.y, keyboardFrameBegin.size.height);
//    DDLogInfo(@"keyboard frame end origin y: %f, height: %f", keyboardFrameEnd.origin.y, keyboardFrameEnd.size.height);
//    int kbHeight = keyboardFrameBegin.origin.y-keyboardFrameEnd.origin.y;
//    // DDLogInfo(@"keyboard height: %d",height);
//    // DDLogInfo(@"origin y before: %f",newFrame.origin.y);
//    
//    // newFrame.origin.y -= height;// keyboardFrameEnd.origin.y - _textFieldContainer.frame.size.height - 10;
//    // DDLogInfo(@"origin y after: %f",newFrame.origin.y);
//    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
//    _scrollView.contentInset = contentInsets;
//    _scrollView.scrollIndicatorInsets = contentInsets;
//    
//    NSInteger totalHeight = self.view.frame.size.height;
//    NSInteger keyboardTop = totalHeight - kbHeight;
//    _offset = _scrollView.contentOffset;
//    
//    NSInteger loginButtonBottom =(_bCreateIdentity.frame.origin.y + _bCreateIdentity.frame.size.height);
//    NSInteger delta = keyboardTop - loginButtonBottom;
//    //  DDLogInfo(@"delta %d loginBottom %d keyboardtop: %d", delta, loginButtonBottom, keyboardTop);
//    
//    if (delta < 0 ) {
//        
//        
//        CGPoint scrollPoint = CGPointMake(0.0, -delta);
//        //  DDLogInfo(@"scrollPoint y: %f", scrollPoint.y);
//        [_scrollView setContentOffset:scrollPoint animated:YES];
//    }
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
//    NSDictionary* info = [aNotification userInfo];
//    NSInteger  kbHeight = [UIUtils keyboardHeightAdjustedForOrientation: [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size];
//    
//    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
//    _scrollView.contentInset = contentInsets;
//    _scrollView.scrollIndicatorInsets = contentInsets;
//    
//    NSInteger totalHeight = self.view.frame.size.height;
//    NSInteger keyboardTop = totalHeight - kbHeight;
//    _offset = _scrollView.contentOffset;
//    
//    NSInteger loginButtonBottom =(_bCreateIdentity.frame.origin.y + _bCreateIdentity.frame.size.height);
//    NSInteger delta = keyboardTop - loginButtonBottom;
//    //  DDLogInfo(@"delta %d loginBottom %d keyboardtop: %d", delta, loginButtonBottom, keyboardTop);
//    
//    if (delta < 0 ) {
//        
//        
//        CGPoint scrollPoint = CGPointMake(0.0, -delta);
//        //  DDLogInfo(@"scrollPoint y: %f", scrollPoint.y);
//        [_scrollView setContentOffset:scrollPoint animated:YES];
//    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
//    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
//    _scrollView.contentInset = contentInsets;
//    _scrollView.scrollIndicatorInsets = contentInsets;
//    [_scrollView setContentOffset:_offset animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)actionButtonPressed:(id)sender
{
    [self createIdentity];
}
@end
