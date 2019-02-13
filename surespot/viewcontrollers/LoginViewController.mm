 //
//  SurespotViewController.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "LoginViewController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "NetworkController.h"
#import "NSData+Base64.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "DDLog.h"
#import "RestoreIdentitiesViewController.h"
#import "RemoveIdentityFromDeviceViewController.h"
#import "SwipeViewController.h"
#import "HelpViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface LoginViewController ()
@property (atomic, strong) NSArray * identityNames;
@property (atomic, strong) id progressView;
@property (nonatomic, assign) CGFloat delta;
@property (nonatomic, assign) CGPoint offset;
@property (strong, nonatomic) IBOutlet UITextField *textPassword;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;

- (IBAction)login:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bLogin;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UISwitch *storePassword;
@property (strong, nonatomic) IBOutlet UILabel *storeKeychainLabel;
@property (strong, readwrite, nonatomic) REMenu *menu;
@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_textPassword setPlaceholder:NSLocalizedString(@"password", nil)];
    [self.navigationItem setTitle:NSLocalizedString(@"login", nil)];
    [self loadIdentityNames];
    [self registerForKeyboardNotifications];
    self.navigationController.navigationBar.translucent = NO;
    
    NSString * lastUser = [[NSUserDefaults standardUserDefaults] stringForKey:@"last_user"];
    NSInteger index = 0;
    
    if (lastUser) {
        index = [_identityNames indexOfObject:lastUser];
        if (index == NSNotFound) {
            index = 0;
        }
    }
    
    [_userPicker selectRow:index inComponent:0 animated:YES];
    
    [self updatePassword:[_identityNames objectAtIndex:index]];
    [self.storePassword setTintColor:[UIUtils surespotBlue]];
    [self.storePassword setOnTintColor:[UIUtils surespotBlue]];
    [self.bLogin setTintColor:[UIUtils surespotBlue]];
    [self.bLogin setTitle:NSLocalizedString(@"login", nil) forState:UIControlStateNormal];
    //  _textPassword.returnKeyType = UIReturnKeyGo;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"menu",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    
    _storeKeychainLabel.text = NSLocalizedString(@"store_password_in_keychain", nil);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification) name:@"openedFromNotification" object:nil];
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
    DDLogInfo(@"keyboardFrameDidChange");
    CGRect keyboardEndFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardBeginFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    //  UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    //  NSTimeInterval animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] integerValue];
    
    //  [UIView beginAnimations:nil context:nil];
    //  [UIView setAnimationDuration:animationDuration];
    //  [UIView setAnimationCurve:animationCurve];
    
    
    
    
//    CGRect newFrame = _textFieldContainer.frame;
    CGRect keyboardFrameEnd = [self.view convertRect:keyboardEndFrame toView:nil];
    
    
    CGRect keyboardFrameBegin = [self.view convertRect:keyboardBeginFrame toView:nil];
    DDLogInfo(@"keyboard frame begin origin y: %f, height: %f", keyboardFrameBegin.origin.y, keyboardFrameBegin.size.height);
    DDLogInfo(@"keyboard frame end origin y: %f, height: %f", keyboardFrameEnd.origin.y, keyboardFrameEnd.size.height);
    int kbHeight = keyboardFrameBegin.origin.y-keyboardFrameEnd.origin.y;
   // DDLogInfo(@"keyboard height: %d",height);
   // DDLogInfo(@"origin y before: %f",newFrame.origin.y);
    
   // newFrame.origin.y -= height;// keyboardFrameEnd.origin.y - _textFieldContainer.frame.size.height - 10;
   // DDLogInfo(@"origin y after: %f",newFrame.origin.y);
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    
    NSInteger totalHeight = self.view.frame.size.height;
    NSInteger keyboardTop = totalHeight - kbHeight;
    _offset = _scrollView.contentOffset;
    
    NSInteger loginButtonBottom =(_bLogin.frame.origin.y + _bLogin.frame.size.height);
    NSInteger delta = keyboardTop - loginButtonBottom;
    //  DDLogInfo(@"delta %d loginBottom %d keyboardtop: %d", delta, loginButtonBottom, keyboardTop);
    
    if (delta < 0 ) {
        
        
        CGPoint scrollPoint = CGPointMake(0.0, -delta);
        //  DDLogInfo(@"scrollPoint y: %f", scrollPoint.y);
        [_scrollView setContentOffset:scrollPoint animated:YES];
    }
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    NSInteger  kbHeight = [UIUtils keyboardHeightAdjustedForOrientation: [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size];
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    
    NSInteger totalHeight = self.view.frame.size.height;
    NSInteger keyboardTop = totalHeight - kbHeight;
    _offset = _scrollView.contentOffset;
    
    NSInteger loginButtonBottom =(_bLogin.frame.origin.y + _bLogin.frame.size.height);
    NSInteger delta = keyboardTop - loginButtonBottom;
    //  DDLogInfo(@"delta %d loginBottom %d keyboardtop: %d", delta, loginButtonBottom, keyboardTop);
    
    if (delta < 0 ) {
        
        
        CGPoint scrollPoint = CGPointMake(0.0, -delta);
        //  DDLogInfo(@"scrollPoint y: %f", scrollPoint.y);
        [_scrollView setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    [_scrollView setContentOffset:_offset animated:YES];
}



- (IBAction)login:(id)sender {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.textPassword.text;
    
    if ([UIUtils stringIsNilOrEmpty:password]) {
        return;
    }
    
    DDLogVerbose(@"starting login");
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_textPassword resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"login_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        DDLogVerbose(@"getting identity");
        SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
        DDLogVerbose(@"got identity");
        
        if (!identity) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_progressView removeView];
                _progressView = nil;
                
                [UIUtils showToastKey: @"login_check_password" ];
                [_textPassword becomeFirstResponder];
                _textPassword.text = @"";
                
                self.navigationItem.rightBarButtonItem.enabled = YES;
                
            });
            return;
        }
        
        
        
        
        DDLogVerbose(@"creating signature");
        
        NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
        NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
        NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
        
        NSData * signature = [EncryptionController signUsername:identity.username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
        NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
        NSString * signatureString = [signature SR_stringByBase64Encoding];
        
        DDLogVerbose(@"logging in to server");
        [[NetworkController sharedInstance]
         loginWithUsername:identity.username
         andPassword:passwordString
         andSignature: signatureString
         successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON, NSHTTPCookie * cookie) {
             DDLogVerbose(@"login response: %d",  [response statusCode]);
             
             if (_storePassword.isOn) {
                 [[IdentityController sharedInstance] storePasswordForIdentity:username password:password];
             }

             
             [[IdentityController sharedInstance] userLoggedInWithIdentity:identity password: password cookie: cookie reglogin:NO];
             
             UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
             SwipeViewController * svc = [storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"];
             
             NSMutableArray *  controllers = [NSMutableArray new];
             [controllers addObject:svc];
             
             
             //show help view on iphone if tos hasn't been clicked
             BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
             if (!tosClicked && [UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad) {
                 HelpViewController *hvc = [[HelpViewController alloc] initWithNibName:@"HelpView" bundle:nil];
                 [controllers addObject:hvc];
             }
             
             [self.navigationController setViewControllers:controllers animated:YES];
             _textPassword.text = @"";
             
             [_progressView removeView];
             _progressView = nil;
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
             DDLogVerbose(@"response failure: %@",  Error);
             [_progressView removeView];
             _progressView = nil;
             
             switch (responseObject.statusCode) {
                 case 401:
                     [UIUtils showToastKey: @"login_check_password"];
                     _textPassword.text = @"";
                     break;
                 case 403:
                     [UIUtils showToastKey: @"login_update"];
                     break;
                 default:
                     [UIUtils showToastKey: @"login_try_again_later"];
             }
             
             [_textPassword becomeFirstResponder];
             self.navigationItem.rightBarButtonItem.enabled = YES;
             
         }];
    });
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self login: nil];
    [textField resignFirstResponder];
    return NO;
}

- (void)viewDidUnload {
    [self setUserPicker:nil];
    [super viewDidUnload];
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}

-(void) viewDidAppear:(BOOL)animated {
    [self refresh];
}

-(void) refresh {
    [self loadIdentityNames];
    [_userPicker reloadAllComponents];
    if ([_identityNames count] > 0) {
        [self updatePassword:[_identityNames objectAtIndex:[ _userPicker selectedRowInComponent:0]]];
    }
    else {
        _textPassword.text = nil;
        [_storePassword setOn:NO animated:NO];
    }
    [self handleNotification];
}


- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength >= 256) ? NO : YES;
}

-(void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSString * selectedUser = [_identityNames objectAtIndex:row];
    [self updatePassword:selectedUser];
    
}

-(void) updatePassword: (NSString *) username {
    DDLogInfo(@"user changed: %@", username);
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    if (password) {
        _textPassword.text = password;
        [_storePassword setOn:YES animated:NO];
    }
    else {
        _textPassword.text = nil;
        [_storePassword setOn:NO animated:NO];
    }
    
}


-(void) resume:(NSNotification *)notification {
    DDLogInfo(@"resume");
    [_textPassword resignFirstResponder];
}

-(void) showMenu {
    
    if (!_menu) {
        [_textPassword resignFirstResponder];
        _menu = [self createMenu];
        if (_menu) {
            [_menu showSensiblyInView:self.view];
        }
    }
    else {
        [_menu close];
    }
    
}

-(REMenu *) createMenu {
    //menu menu
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    REMenuItem * createItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"create_identity_label", nil) image:[UIImage imageNamed:@"ic_menu_add"] highlightedImage:nil action:^(REMenuItem * item){
        if ([[IdentityController sharedInstance] getIdentityCount] < MAX_IDENTITIES) {
            [self performSegueWithIdentifier: @"createSegue" sender: self];
        }
        else {
            [UIUtils showToastMessage:[NSString stringWithFormat: NSLocalizedString(@"login_max_identities_reached",nil), MAX_IDENTITIES] duration:2];
        }
    }];
    
    [menuItems addObject:createItem];
    
    REMenuItem * restoreItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"import_identities", nil) image:[UIImage imageNamed:@"ic_menu_archive"] highlightedImage:nil action:^(REMenuItem * item){
        RestoreIdentitiesViewController * controller = [[RestoreIdentitiesViewController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
        
    }];
    
    [menuItems addObject:restoreItem];
  
    REMenuItem * removeIdentityItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"remove_identity_from_device", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        RemoveIdentityFromDeviceViewController * controller = [[RemoveIdentityFromDeviceViewController alloc] init];
        controller.selectUsername = username;
        [self.navigationController pushViewController:controller animated:YES];
    }];
    
    [menuItems addObject:removeIdentityItem];
    
    REMenuItem * clearCacheItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"clear_local_cache", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        [UIUtils clearLocalCache];
        [UIUtils showToastKey:@"local_cache_cleared" duration:2];
    }];
    
    [menuItems addObject:clearCacheItem];
    
    return [UIUtils createMenu: menuItems closeCompletionHandler:^{
        _menu = nil;
    }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}

-(void) handleNotification {
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    DDLogInfo(@"handleNotification, defaults: %@", defaults);
    //if we entered app via notification defaults will be set
    NSString * notificationType = [defaults objectForKey:@"notificationType"];
    
    if ([notificationType isEqualToString:@"message"] || [notificationType isEqualToString:@"invite"]) {
        NSString * to = [defaults objectForKey:@"notificationTo"];
        NSInteger index = 0;
        index = [_identityNames indexOfObject:to];
        if (index == NSNotFound) {
            index = 0;
        }
        
        [_userPicker selectRow:index inComponent:0 animated:YES];
        [self updatePassword:to];
    }
}

- (IBAction)storeKeychainValueChanged:(id)sender {
    if (![_storePassword isOn]) {
        NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
        [[IdentityController sharedInstance] clearStoredPasswordForIdentity:username];
    }    
}


@end
