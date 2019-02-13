//
//  SwipeViewController.m
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "SwipeViewController.h"
#import "NetworkController.h"
#import "ChatController.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import <UIKit/UIKit.h>
#import "MessageView.h"
#import "ChatUtils.h"
#import "HomeCell.h"
#import "SurespotControlMessage.h"
#import "FriendDelegate.h"
#import "UIUtils.h"
#import "LoginViewController.h"
#import "DDLog.h"
#import "REMenu.h"
#import "SVPullToRefresh.h"
#import "SurespotConstants.h"
#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "ImageDelegate.h"
#import "MessageView+WebImageCache.h"
#import "SurespotPhoto.h"
#import "HomeCell+WebImageCache.h"
#import "KeyFingerprintViewController.h"
#import "QRInviteViewController.h"
#import "VoiceDelegate.h"
#import "PurchaseDelegate.h"
#import "SurespotSettingsStore.h"
#import "HelpViewController.h"
#import "UIAlertView+Blocks.h"
#import "LoadingView.h"
#import "UsernameAliasMap.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_WARN;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

//#import <QuartzCore/CATransaction.h>

@interface SwipeViewController ()
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@property (nonatomic, strong) UIViewPager * viewPager;
@property (nonatomic, strong) NSMutableDictionary * needsScroll;
@property (strong, readwrite, nonatomic) REMenu *menu;
@property (atomic, assign) NSInteger progressCount;
@property (nonatomic, weak) UIView * backImageView;
@property (atomic, assign) NSInteger scrollingTo;
@property (nonatomic, strong) NSMutableDictionary * bottomIndexPaths;
@property (nonatomic, strong) IASKAppSettingsViewController * appSettingsViewController;
@property (nonatomic, strong) ImageDelegate * imageDelegate;
@property (nonatomic, strong) SurespotMessage * imageMessage;
@property (nonatomic, strong) UIPopoverController * popover;
@property (nonatomic, strong) VoiceDelegate * voiceDelegate;
@property (nonatomic, strong) NSDate * buttonDownDate;
@property (strong, nonatomic) IBOutlet HPGrowingTextView *messageTextView;
@property (strong, nonatomic) IBOutlet HPGrowingTextView *inviteTextView;
@property (nonatomic, strong) NSTimer * buttonTimer;
@property (strong, nonatomic) IBOutlet UIImageView *bgImageView;
@property (nonatomic, assign) BOOL hasBackgroundImage;
@property (nonatomic, strong) IBOutlet SwipeView *swipeView;
@property (nonatomic, strong) UITableView *friendView;
@property (strong, atomic) NSMutableDictionary *chats;
@property (strong, nonatomic) KeyboardState * keyboardState;
@property (strong, nonatomic) IBOutlet UIButton *theButton;
- (IBAction)buttonTouchUpInside:(id)sender;
@property (strong, nonatomic) IBOutlet UIView *textFieldContainer;
@property (atomic, strong) ALAssetsLibrary * assetLibrary;
@property (atomic, strong) LoadingView * progressView;
@property (nonatomic) float savedTextHeight;
@end
@implementation SwipeViewController


const Float32 voiceRecordDelay = 0.3;

- (void)viewDidLoad
{
    DDLogVerbose(@"swipeviewdidload %@", self);
    [super viewDidLoad];
    
    _assetLibrary = [ALAssetsLibrary new];
    
    _needsScroll = [NSMutableDictionary new];
    
    _dateFormatQueue = dispatch_queue_create("date format queue", NULL);
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _chats = [[NSMutableDictionary alloc] init];
    
    //configure swipe view
    _swipeView.alignment = SwipeViewAlignmentCenter;
    _swipeView.pagingEnabled = YES;
    _swipeView.wrapEnabled = NO;
    _swipeView.truncateFinalPage =NO ;
    _swipeView.delaysContentTouches = YES;
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    [self registerForKeyboardNotifications];
    
    
    UIButton *backButton = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 36.0f, 36.0f)];
    
    
    UIImage * backImage = [UIImage imageNamed:@"surespot_logo"];
    [backButton setBackgroundImage:backImage  forState:UIControlStateNormal];
    [backButton setContentMode:UIViewContentModeScaleAspectFit];
    _backImageView = backButton;
    
    [backButton addTarget:self action:@selector(backPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backButtonItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    self.navigationItem.leftBarButtonItem = backButtonItem;
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"menu",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showMenuMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    self.navigationItem.title = [[IdentityController sharedInstance] getLoggedInUser];
    
    
    //don't swipe to back stack
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
    
    
    //listen for  notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshMessages:) name:@"refreshMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshHome:) name:@"refreshHome" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFriend:) name:@"deleteFriend" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startProgress:) name:@"startProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopProgress:) name:@"stopProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unauthorized:) name:@"unauthorized" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newMessage:) name:@"newMessage" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(invite:) name:@"invite" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(inviteAccepted:) name:@"inviteAccepted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purchaseStatusChanged:) name:@"purchaseStatusChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backgroundImageChanged:) name:@"backgroundImageChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNotification) name:@"openedFromNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userSwitch) name:@"userSwitch" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSwipeViewData) name:@"reloadSwipeView" object:nil];
    
    
    _viewPager = [[UIViewPager alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 30)];
    _viewPager.autoresizingMask =UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_viewPager];
    _viewPager.delegate = self;
    
    
    //open active tabs, don't load data now well get it after connect
    for (Friend * afriend in [[[ChatController sharedInstance] getHomeDataSource] friends]) {
        if ([afriend isChatActive]) {
            [self loadChat:[afriend name] show:NO availableId: -1 availableControlId:-1];
        }
    }
    
    //setup the button
    _theButton.layer.cornerRadius = 35;
    _theButton.layer.borderColor = [[UIUtils surespotBlue] CGColor];
    _theButton.layer.borderWidth = 3.0f;
    _theButton.backgroundColor = [UIColor whiteColor];
    _theButton.opaque = YES;
    
    [self updateTabChangeUI];
    
    [[ChatController sharedInstance] resume];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    _scrollingTo = -1;
    
    //app settings
    _appSettingsViewController = [IASKAppSettingsViewController new];
    _appSettingsViewController.settingsStore = [[SurespotSettingsStore alloc] initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]];
    _appSettingsViewController.delegate = self;
    
    
    _messageTextView.enablesReturnKeyAutomatically = NO;
    [_messageTextView setFont:[UIFont systemFontOfSize:14]];
    [_messageTextView setMaxNumberOfLines:3];
    _messageTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageTextView.delegate = self;
    [_messageTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
    [_messageTextView.layer setBorderWidth:0.5];
    [_messageTextView setBackgroundColor:[UIColor clearColor]];
    _messageTextView.layer.cornerRadius = 5;
    
    _inviteTextView.enablesReturnKeyAutomatically = NO;
    [_inviteTextView setFont:[UIFont systemFontOfSize:14]];
    [_inviteTextView setMaxNumberOfLines:1];
    _inviteTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _inviteTextView.delegate = self;
    [_inviteTextView.layer setBorderColor:[[UIColor grayColor] CGColor]];
    [_inviteTextView.layer setBorderWidth:0.5];
    [_inviteTextView setBackgroundColor:[UIColor clearColor]];
    _inviteTextView.layer.cornerRadius = 5;
    [_inviteTextView.internalTextView setAutocorrectionType:UITextAutocorrectionTypeNo];
    [_inviteTextView.internalTextView setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [_inviteTextView.internalTextView setSpellCheckingType:UITextSpellCheckingTypeNo];
    
    [self setTextBoxHints];
}

- (void)growingTextView:(HPGrowingTextView *)growingTextView willChangeHeight:(float)height
{
    DDLogInfo(@"growingTextView height: %f", height);
    float diff = (growingTextView.frame.size.height - height);
    
    CGRect containerRect = _textFieldContainer.frame;
    containerRect.size.height -= diff;
    containerRect.origin.y += diff;
    _textFieldContainer.frame = containerRect;
    
    [self adjustTableViewHeight:-diff];
}

-(void) adjustTableViewHeight: (NSInteger) height {
    
    CGRect frame = _swipeView.frame;
    frame.size.height -= height;
    _swipeView.frame = frame;
    
    UITableView * tableView = [_chats objectForKey: [self getCurrentTabName]];
    CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y + height);
    [tableView setContentOffset:newOffset animated:NO];
}

-(void)growingTextViewDidChange:(HPGrowingTextView *)growingTextView {
    [self updateTabChangeUI];
}

/*
 -(void)growingTextView:(HPGrowingTextView *)growingTextView didChangeHeight:(float)height {
    
}
*/

- (BOOL) growingTextView:(HPGrowingTextView *)growingTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *) string
{
    
    if ([string isEqualToString:@"\n"]) {
        [self handleTextAction];
        return NO;
    }
    
    if (growingTextView == _inviteTextView) {
        NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
        NSString * newString = [string stringByTrimmingCharactersInSet:alphaSet];
        if (![newString isEqualToString:@""]) {
            return NO;
        }
        
        NSUInteger newLength = [growingTextView.text length] + [newString length] - range.length;
        return (newLength >= 20) ? NO : YES;
    }
    else {
        if (growingTextView == _messageTextView) {
            NSUInteger newLength = [_messageTextView.text length] + [string length] - range.length;
            return (newLength >= 1024) ? NO : YES;
        }
    }
    return YES;
}


-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //show help in popover on ipad if it hasn't been shown yet
    BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
    if (!tosClicked && [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        
        HelpViewController * hvc = [[HelpViewController alloc]                                                                                                            initWithNibName:@"HelpView" bundle:nil];
        
        _popover = [[UIPopoverController alloc] initWithContentViewController: hvc] ;
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
        hvc.poController = _popover;
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:YES];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
    }
    
    [self showHeader];
    [self handleNotification];
    
}


-(void) dealloc {
    DDLogVerbose(@"dealloc");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(void) pause: (NSNotification *)  notification{
    DDLogVerbose(@"pause");
    [[ChatController sharedInstance] pause];
    
}


-(void) resume: (NSNotification *) notification {
    DDLogVerbose(@"resume");
    [[ChatController sharedInstance] resume];
    
}



- (void)registerForKeyboardNotifications
{
    
    //use old positioning pre ios 8
    
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
    if (![_messageTextView isFirstResponder] && ![_inviteTextView isFirstResponder]) {
        // if the message text view isn't the first responder, don't adjust control offsets
        return;
    }

    DDLogInfo(@"keyboardFrameDidChange");
    CGRect keyboardEndFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardBeginFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    //  UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    //  NSTimeInterval animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] integerValue];
    
    //  [UIView beginAnimations:nil context:nil];
    //  [UIView setAnimationDuration:animationDuration];
    //  [UIView setAnimationCurve:animationCurve];
    
    CGRect newFrame = _textFieldContainer.frame;
    CGRect originalFrame = _textFieldContainer.frame;
    CGRect keyboardFrameEnd = [self.view convertRect:keyboardEndFrame toView:nil];
    CGRect keyboardFrameBegin = [self.view convertRect:keyboardBeginFrame toView:nil];
    //DDLogInfo(@"keyboard frame begin origin y: %f, height: %f", keyboardFrameBegin.origin.y, keyboardFrameBegin.size.height);
    //DDLogInfo(@"keyboard frame end origin y: %f, height: %f", keyboardFrameEnd.origin.y, keyboardFrameEnd.size.height);
    int height = keyboardFrameBegin.origin.y - keyboardFrameEnd.origin.y;
    
    //DDLogInfo(@"keyboard height: %d",height);
    //DDLogInfo(@"origin y before: %f",newFrame.origin.y);
    //NSLog(@"textFieldContainer frame: origin x: %f, origin y: %f, height: %f",_textFieldContainer.frame.origin.x, _textFieldContainer.frame.origin.y, _textFieldContainer.frame.size.height);
    
    newFrame.origin.y = keyboardEndFrame.origin.y - newFrame.size.height;
    CGRect convertedToScreenCoords = [self.view convertRect:newFrame fromView:nil];
    newFrame.origin.y = convertedToScreenCoords.origin.y;
    _textFieldContainer.frame = newFrame;
    
    //NSLog(@"NEW textFieldContainer frame: origin x: %f, origin y: %f, height: %f",_textFieldContainer.frame.origin.x, _textFieldContainer.frame.origin.y, _textFieldContainer.frame.size.height);
    
    CGRect frame = _swipeView.frame;
    //NSLog(@"swipeview frame: origin x: %f, origin y: %f, height: %f",_swipeView.frame.origin.x, _swipeView.frame.origin.y, _swipeView.frame.size.height);
    CGRect actualSwipeViewTop = [self.view convertRect:frame fromView:nil];
    float f = self.view.frame.size.height;
    if (height <= 0) {
        frame.size.height = f - fabs(actualSwipeViewTop.origin.y) - newFrame.size.height;
    } else {
        frame.size.height = f - fabs(actualSwipeViewTop.origin.y) - keyboardEndFrame.size.height - newFrame.size.height;
    }
    
    if (frame.size.height <= 5) {
        frame.size.height = 10; // get a bigger screen, geez
    }
    
    _swipeView.frame = frame;
    //NSLog(@"NEW swipeview frame: origin x: %f, origin y: %f, height: %f",_swipeView.frame.origin.x, _swipeView.frame.origin.y, _swipeView.frame.size.height);
    
    CGRect buttonFrame = _theButton.frame;
    buttonFrame.origin.y = newFrame.origin.y - 16;
    _theButton.frame = buttonFrame;
    
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            UITableView * tableView = [_chats objectForKey:key];
            
            UITableViewCell * bottomCell = nil;
            NSArray * visibleCells = [tableView visibleCells];
            if ([visibleCells count ] > 0) {
                bottomCell = [visibleCells objectAtIndex:[visibleCells count]-1];
            }
            
            if (bottomCell) {
                CGRect aRect = self.view.frame;
                
                if (!CGRectContainsPoint(aRect, bottomCell.frame.origin) ) {
                    float change = originalFrame.origin.y - newFrame.origin.y;
                    CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y + change);
                    [tableView setContentOffset:newOffset animated:NO];
                }
            }
        }
    }
    
    
    [self.view layoutIfNeeded];
    // [UIView commitAnimations];
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification {
    DDLogInfo(@"keyboard shown");
    
    
    
    if (!_keyboardState) {
        NSDictionary* info = [aNotification userInfo];
        CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
        CGFloat keyboardHeight = [UIUtils keyboardHeightAdjustedForOrientation:keyboardRect.size];
        
        _keyboardState = [[KeyboardState alloc] init];
        _keyboardState.keyboardHeight = keyboardHeight;
        
        CGRect textFieldFrame = _textFieldContainer.frame;
        textFieldFrame.origin.y -= keyboardHeight;
        _textFieldContainer.frame = textFieldFrame;
        
        CGRect frame = _swipeView.frame;
        frame.size.height -= keyboardHeight;
        _swipeView.frame = frame;
        
        CGRect buttonFrame = _theButton.frame;
        buttonFrame.origin.y -= keyboardHeight;
        _theButton.frame = buttonFrame;
        
        @synchronized (_chats) {
            for (NSString * key in [_chats allKeys]) {
                UITableView * tableView = [_chats objectForKey:key];
                
                UITableViewCell * bottomCell = nil;
                NSArray * visibleCells = [tableView visibleCells];
                if ([visibleCells count ] > 0) {
                    bottomCell = [visibleCells objectAtIndex:[visibleCells count]-1];
                }
                
                if (bottomCell) {
                    CGRect aRect = self.view.frame;
                    aRect.size.height -= keyboardHeight;
                    if (!CGRectContainsPoint(aRect, bottomCell.frame.origin) ) {
                        CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y + keyboardHeight);
                        [tableView setContentOffset:newOffset animated:NO];
                    }
                }
            }
        }
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    [self handleKeyboardHide];
}

- (void) handleKeyboardHide {
    DDLogInfo(@"keyboard hide");
    if (self.keyboardState) {
        //reset content position
        @synchronized (_chats) {
            for (NSString * key in [_chats allKeys]) {
                UITableView * tableView = [_chats objectForKey:key];
                CGPoint newOffset = CGPointMake(0, tableView.contentOffset.y - _keyboardState.keyboardHeight);
                [tableView setContentOffset:newOffset animated:NO];
            }
        }
        
        CGRect swipeFrame = _swipeView.frame;
        swipeFrame.size.height += _keyboardState.keyboardHeight;
        _swipeView.frame = swipeFrame;
        [_swipeView setNeedsLayout];
        
        CGRect textFieldFrame = _textFieldContainer.frame;
        textFieldFrame.origin.y += self.keyboardState.keyboardHeight;
        _textFieldContainer.frame = textFieldFrame;
        
        
        CGRect buttonFrame = _theButton.frame;
        buttonFrame.origin.y += self.keyboardState.keyboardHeight;
        _theButton.frame = buttonFrame;
        
        self.keyboardState = nil;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                duration:(NSTimeInterval)duration
{
    DDLogInfo(@"will rotate");
    if ([UIUtils isIOS8Plus]) {
        [self resignAllResponders];
    }
    
    _swipeView.suppressScrollEvent = YES;
    
    
    _bottomIndexPaths = [NSMutableDictionary new];
    
    NSArray * visibleCells = [_friendView indexPathsForVisibleRows];
    if ([visibleCells count ] > 0) {
        
        id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
        DDLogVerbose(@"saving index path %@ for home", indexPath );
        [_bottomIndexPaths setObject: indexPath forKey: @"" ];
        
    }
    
    //save scroll indices
    
    @synchronized (_chats) {
        for (NSString * key in [_chats allKeys]) {
            
            UITableView * tableView = [_chats objectForKey:key];
            
            NSArray * visibleCells = [tableView indexPathsForVisibleRows];
            
            if ([visibleCells count ] > 0) {
                
                id indexPath =[visibleCells objectAtIndex:[visibleCells count]-1];
                
                DDLogVerbose(@"saving index path %@ for key %@", indexPath , key);
                
                [_bottomIndexPaths setObject: indexPath forKey: key ];
                
            }
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    DDLogInfo(@"did rotate");
    
    _swipeView.suppressScrollEvent= NO;
    
    [self showHeader];
    [self restoreScrollPositions];
    [self scrollToBottomOfTextView];
}

-(void)scrollToBottomOfTextView
{
    if(_messageTextView.text.length > 0 ) {
        NSRange bottom = NSMakeRange(_messageTextView.text.length -1, 1);
        [_messageTextView scrollRangeToVisible:bottom];
    }
}

-(void)popoverController:(UIPopoverController *)popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing *)view {
    CGFloat x =self.view.bounds.size.width;
    CGFloat y =self.view.bounds.size.height;
    DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
    
    CGRect newRect = CGRectMake(x/2,y/2, 1,1 );
    *rect = newRect;
}


-(void) restoreScrollPositions {
    if (_bottomIndexPaths) {
        for (id key in [_bottomIndexPaths allKeys]) {
            if ([key isEqualToString:@""]) {
                
                if (![self getCurrentTabName]) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogVerbose(@"Scrolling home view to index %@", indexPath);
                    [self scrollTableViewToCell:_friendView indexPath: indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
            else {
                if ([[self getCurrentTabName] isEqualToString:key]) {
                    id indexPath =[_bottomIndexPaths objectForKey:key];
                    DDLogVerbose(@"Scrolling %@ view to index %@", key,indexPath);
                    
                    UITableView * tableView = [_chats objectForKey:key];
                    [self scrollTableViewToCell:tableView indexPath:indexPath];
                    [_bottomIndexPaths removeObjectForKey:key ];
                }
            }
        }
    }
    
}

-(void) showHeader {
    //if we're on iphone in landscape, hide the nav bar and status bar
    if ([[ UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone &&
        UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation])) {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
        
        //if we're in landscape on iphone hide the menu
        [_menu close];
    }
    else {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
        [self.navigationController setNavigationBarHidden:NO animated:YES];
    }
}

- (void) swipeViewDidScroll:(SwipeView *)scrollView {
    DDLogVerbose(@"swipeViewDidScroll");
    [_viewPager scrollViewDidScroll: scrollView.scrollView];
    
}

-(NSUInteger)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return ![_voiceDelegate isRecording];
}

-(void) switchToPageIndex:(NSInteger)page {
    _scrollingTo = page;
    [_swipeView scrollToPage:page duration:0.5f];
}

-(NSInteger) currentPage {
    return [_swipeView currentPage];
}

-(NSInteger) pageCount {
    return [self numberOfItemsInSwipeView:nil];
}

-(NSString * ) titleForLabelForPage:(NSInteger)page {
    DDLogVerbose(@"titleForLabelForPage %d", page);
    if (page == 0) {
        return @"home";
    }
    else {
        return [self aliasForPage:page];    }
    
    return nil;
}

-(NSString * ) nameForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[[self sortedAliasedChats] objectAtIndex:page-1] username];
            }
        }
    }
    
    return nil;
}

-(NSString * ) aliasForPage:(NSInteger)page {
    
    if (page == 0) {
        return nil;
    }
    else {
        @synchronized (_chats) {
            if ([_chats count] > 0) {
                return [[[self sortedAliasedChats] objectAtIndex:page-1] alias];
            }
        }
    }
    
    return nil;
}

- (NSInteger)numberOfItemsInSwipeView:(SwipeView *)swipeView
{
    @synchronized (_chats) {
        return 1 + [_chats count];
    }
}

- (UIView *)swipeView:(SwipeView *)swipeView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view
{
    DDLogVerbose(@"view for item at index %d", index);
    if (index == 0) {
        if (!_friendView) {
            DDLogVerbose(@"creating friend view");
            
            _friendView = [[UITableView alloc] initWithFrame:swipeView.frame style: UITableViewStylePlain];
            _friendView.backgroundColor = [UIColor clearColor];
            [_friendView setSeparatorColor:[UIUtils surespotSeparatorGrey]];
            [_friendView registerNib:[UINib nibWithNibName:@"HomeCell" bundle:nil] forCellReuseIdentifier:@"HomeCell"];
            _friendView.delegate = self;
            _friendView.dataSource = self;
            if ([_friendView respondsToSelector:@selector(setSeparatorInset:)]) {
                [_friendView setSeparatorInset:UIEdgeInsetsZero];
            }
            
            [self addLongPressGestureRecognizer:_friendView];
        }
        
        DDLogVerbose(@"returning friend view %@", _friendView);
        //return view
        return _friendView;
        
        
    }
    else {
        DDLogVerbose(@"returning chat view");
        @synchronized (_chats) {
            NSArray *keys = [self sortedAliasedChats];
            if ([keys count] > index - 1) {
                
                id aKey = [keys objectAtIndex:index -1];
                id anObject = [_chats objectForKey:[aKey username]];
                
                return anObject;
            }
            else {
                return nil;
            }
        }
    }
    
}

-(void) addLongPressGestureRecognizer: (UITableView  *) tableView {
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(tableLongPress:) ];
    lpgr.minimumPressDuration = .7; //seconds
    [tableView addGestureRecognizer:lpgr];
    
}



- (void)swipeViewCurrentItemIndexDidChange:(SwipeView *)swipeView
{
    NSInteger currPage = swipeView.currentPage;
    DDLogInfo(@"swipeview index changed to %d scrolling to: %d", currPage, _scrollingTo);
    
    UITableView * tableview;
    if (currPage == 0) {
        [[ChatController sharedInstance] setCurrentChat:nil];
        tableview = _friendView;
        
        //stop pulsing
        [UIUtils stopPulseAnimation:_backImageView];
        _scrollingTo = -1;
        
        [tableview reloadData];
        
        if (_bottomIndexPaths) {
            id path = [_bottomIndexPaths objectForKey:@""];
            if (path) {
                [self scrollTableViewToCell:_friendView indexPath:path];
                [_bottomIndexPaths removeObjectForKey:@""];
            }
        }
        
        //update button
        [self updateTabChangeUI];
        [self updateKeyboardState:YES];
        
    }
    else {
        @synchronized (_chats) {
            if (_scrollingTo == currPage || _scrollingTo == -1) {
                tableview = [self sortedValues][swipeView.currentPage-1];
                
                UsernameAliasMap * map = [self sortedAliasedChats][currPage-1];
                [[ChatController sharedInstance] setCurrentChat: map.username];
                _scrollingTo = -1;
                
                if (![[[ChatController sharedInstance] getHomeDataSource] hasAnyNewMessages]) {
                    //stop pulsing
                    [UIUtils stopPulseAnimation:_backImageView];
                }
                
                [tableview reloadData];
                
                //scroll if we need to
                BOOL scrolledUsingIndexPath = NO;
                
                //if we've got saved scroll positions
                if (_bottomIndexPaths) {
                    id path = [_bottomIndexPaths objectForKey:map.username];
                    if (path) {
                        DDLogVerbose(@"scrolling using saved index path for %@",map.username);
                        [self scrollTableViewToCell:tableview indexPath:path];
                        [_bottomIndexPaths removeObjectForKey:map.username];
                        scrolledUsingIndexPath = YES;
                    }
                }
                
                
                if (!scrolledUsingIndexPath) {
                    @synchronized (_needsScroll ) {
                        id needsit = [_needsScroll  objectForKey:map.username];
                        if (needsit) {
                            DDLogVerbose(@"scrolling %@ to bottom",map.username);
                            [self performSelector:@selector(scrollTableViewToBottom:) withObject:tableview afterDelay:0.5];
                            [_needsScroll removeObjectForKey:map.username];
                        }
                    }
                }
                
                
                //update button
                [self updateTabChangeUI];
                [self updateKeyboardState:NO];
            }
        }
    }
}

- (void)swipeView:(SwipeView *)swipeView didSelectItemAtIndex:(NSInteger)index
{
    DDLogVerbose(@"Selected item at index %i", index);
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    DDLogVerbose(@"number of sections");
    // Return the number of sections.
    return 1;
}

- (NSInteger) indexForTableView: (UITableView *) tableView {
    if (tableView == _friendView) {
        return 0;
    }
    @synchronized (_chats) {
        NSArray * sortedChats = [self sortedAliasedChats];
        for (int i=0; i<[_chats count]; i++) {
            if ([_chats objectForKey:[[sortedChats objectAtIndex:i] username]] == tableView) {
                return i+1;
                
            }
            
        }}
    
    return NSNotFound;
    
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSUInteger index = [self indexForTableView:tableView];
    
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    DDLogVerbose(@"number of rows in section, index: %d", index);
    // Return the number of rows in the section
    if (index == 0) {
        if (![[ChatController sharedInstance] getHomeDataSource]) {
            DDLogVerbose(@"returning 1 rows");
            return 1;
        }
        
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        return count == 0 ? 1 : count;
    }
    else {
        NSInteger chatIndex = index-1;
        UsernameAliasMap * aliasMap;
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedAliasedChats];
            if(chatIndex >= 0 && chatIndex < keys.count ) {
                aliasMap = [keys objectAtIndex:chatIndex];
            }
        }
        
        NSInteger count = [[ChatController sharedInstance] getDataSourceForFriendname: aliasMap.username].messages.count;
        return count == 0 ? 1 : count;
        
    }
    
    return 1;
    
}



- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    //  DDLogVerbose(@"height for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        return 0;
    }
    
    
    
    
    if (index == 0) {
        
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        //if count is 0 we returned 1 for 0 rows so make the single row take up the whole height
        if (count == 0) {
            return tableView.frame.size.height;
        }
        
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        if ([afriend isInviter] ) {
            return 70;
        }
        else {
            return 44;
        }
    }
    else {
        @synchronized (_chats) {
            
            NSArray *keys = [self sortedAliasedChats];
            UsernameAliasMap  * map = [keys objectAtIndex:index -1];
            
            NSString * username = map.username;
            NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
            
            
            //if count is 0 we returned 1 for 0 rows so
            if (messages.count == 0) {
                return tableView.frame.size.height;
            }
            
            
            if (messages.count > 0 && (indexPath.row < messages.count)) {
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
                NSInteger height = 44;
                if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
                    height = message.rowLandscapeHeight;
                }
                else {
                    height  = message.rowPortraitHeight;
                }
                
                if (height > 0) {
                    return height;
                }
                
                else {
                    return 44;
                }
            }
            else {
                return 0;
            }
        }
    }
    
}

-(UIColor *) getTextColor {
    return _hasBackgroundImage ? [UIUtils surespotGrey] : [UIColor blackColor];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    
    NSInteger index = [self indexForTableView:tableView];
    
    if (index == NSNotFound) {
        index = [_swipeView indexOfItemViewOrSubview:tableView];
    }
    
    
    //  DDLogVerbose(@"cell for row, index: %d, indexPath: %@", index, indexPath);
    if (index == NSNotFound) {
        static NSString *CellIdentifier = @"Cell";
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        return cell;
        
    }
    
    
    
    if (index == 0) {
        NSInteger count =[[[ChatController sharedInstance] getHomeDataSource].friends count];
        
        if (count == 0) {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"no_friends", nil);
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.textColor = [self getTextColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        
        static NSString *CellIdentifier = @"HomeCell";
        HomeCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Configure the cell...
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        cell.friendLabel.text = afriend.nameOrAlias;
        cell.friendLabel.textColor = [self getTextColor];
        cell.backgroundColor = [UIColor clearColor];
        cell.friendName = afriend.name;
        cell.friendDelegate = [ChatController sharedInstance];
        
        BOOL isInviter =[afriend isInviter];
        
        [cell.ignoreButton setHidden:!isInviter];
        [cell.acceptButton setHidden:!isInviter];
        [cell.blockButton setHidden:!isInviter];
        
        
        cell.activeStatus.hidden = ![afriend isChatActive];
        cell.activeStatus.foregroundColor = [UIUtils surespotBlue];
        
        if (afriend.isInvited || afriend.isInviter || afriend.isDeleted) {
            cell.friendStatus.hidden = NO;
            
            if (afriend.isDeleted) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_deleted", nil);
            }
            
            if (afriend.isInvited) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_invited", nil);
            }
            
            if (afriend.isInviter) {
                cell.friendStatus.text = NSLocalizedString(@"friend_status_is_inviting", nil);
                [cell.blockButton setTitle:NSLocalizedString(@"block_underline", nil) forState:UIControlStateNormal];
                [cell.ignoreButton setTitle:NSLocalizedString(@"ignore_underline", nil) forState:UIControlStateNormal];
                [cell.acceptButton setTitle:NSLocalizedString(@"accept_underline", nil) forState:UIControlStateNormal];
            }
            cell.friendStatus.textAlignment = NSTextAlignmentCenter;
            cell.friendStatus.lineBreakMode = NSLineBreakByWordWrapping;
            cell.friendStatus.numberOfLines = 0;
            
            
        }
        else {
            cell.friendStatus.hidden = YES;
        }
        
        cell.messageNewView.hidden = !afriend.hasNewMessages;
        
        UIView *bgColorView = [[UIView alloc] init];
        bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
        bgColorView.layer.masksToBounds = YES;
        cell.selectedBackgroundView = bgColorView;
        
        if ([afriend hasFriendImageAssigned]) {
            EncryptionParams * ep = [[EncryptionParams alloc] initWithOurUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                                       ourVersion:afriend.imageVersion
                                                                    theirUsername:afriend.name
                                                                     theirVersion:afriend.imageVersion
                                                                               iv:afriend.imageIv];
            
            DDLogVerbose(@"setting friend image for %@ to %@", afriend.name, afriend.imageUrl);
            [cell setImageForFriend:afriend withEncryptionParams: ep placeholderImage:  [UIImage imageNamed:@"surespot_logo"] progress:^(NSUInteger receivedSize, long long expectedSize) {
                
            } completed:^(id image, NSString * mimeType, NSError *error, SDImageCacheType cacheType) {
                
            } retryAttempt:0];
        }
        else {
            DDLogVerbose(@"no friend image for %@", afriend.name);
            cell.friendImage.image = [UIImage imageNamed:@"surespot_logo"];
            [cell.friendImage setAlpha:.5];
        }
        
        return cell;
    }
    else {
        UsernameAliasMap * aliasMap;
        @synchronized (_chats) {
            NSArray *keys = [self sortedAliasedChats];
            
            if ([keys count] > index - 1) {
                aliasMap = [keys objectAtIndex:index -1];
            }
            else {
                static NSString *CellIdentifier = @"Cell";
                UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
                cell.backgroundColor = [UIColor clearColor];
                cell.userInteractionEnabled = NO;
                return cell;
            }
        }
        
        NSString * username =  aliasMap.username;
        NSArray * messages = [[ChatController sharedInstance] getDataSourceForFriendname: username].messages;
        
        
        if (messages.count == 0) {
            DDLogVerbose(@"no chat messages");
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.textLabel.text = NSLocalizedString(@"no_messages", nil);
            cell.textLabel.textColor = [self getTextColor];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.userInteractionEnabled = NO;
            return cell;
        }
        
        
        if (messages.count > 0 && indexPath.row < messages.count) {
            
            
            SurespotMessage * message =[messages objectAtIndex:indexPath.row];
            NSString * plainData = [message plainData];
            static NSString *OurCellIdentifier = @"OurMessageView";
            static NSString *TheirCellIdentifier = @"TheirMessageView";
            
            NSString * cellIdentifier;
            BOOL ours = NO;
            
            if ([ChatUtils isOurMessage:message]) {
                ours = YES;
                cellIdentifier = OurCellIdentifier;
                
            }
            else {
                cellIdentifier = TheirCellIdentifier;
            }
            MessageView *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
            if (!ours) {
                
                cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
            }
            cell.backgroundColor = [UIColor clearColor];
            cell.message = message;
            cell.messageLabel.text = plainData;
            cell.messageLabel.textColor = [self getTextColor];
            
            NSDictionary * linkAttributes = [NSMutableDictionary dictionary];
            [linkAttributes setValue:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];
            [linkAttributes setValue:(__bridge id)[[UIUtils surespotBlue] CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
            
            cell.messageLabel.linkAttributes = linkAttributes;
            cell.messageLabel.delegate = self;
            
            
            cell.messageLabel.enabledTextCheckingTypes = NSTextCheckingTypeLink//phone number seems flaky..we have copy so not the end of teh world
            | NSTextCheckingTypePhoneNumber;
            
            cell.messageSize.textColor = [self getTextColor];
            cell.messageStatusLabel.textColor = [self getTextColor];
            
            cell.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
            UIView *bgColorView = [[UIView alloc] init];
            bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
            bgColorView.layer.masksToBounds = YES;
            cell.selectedBackgroundView = bgColorView;
            DDLogVerbose(@"message text x position: %f, width: %f", cell.messageLabel.frame.origin.x, cell.messageLabel.frame.size.width);
            
            if (message.errorStatus > 0) {
                
                NSString * errorText = [UIUtils getMessageErrorText: message.errorStatus mimeType:message.mimeType];
                DDLogVerbose(@"setting error status %@", errorText);
                [cell.messageStatusLabel setText: errorText];
                cell.messageSentView.foregroundColor = [UIColor blackColor];
            }
            else {
                
                if (message.serverid <= 0) {
                    DDLogVerbose(@"setting message sending");
                    cell.messageStatusLabel.text = NSLocalizedString(@"message_sending",nil);
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor blackColor];
                    }
                }
                else {
                    if (!message.formattedDate) {
                        message.formattedDate = [self stringFromDate:[message dateTime]];
                    }
                    
                    if (ours) {
                        cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                    }
                    
                    if ((!message.plainData && [message.mimeType isEqualToString:MIME_TYPE_TEXT]) ||
                        (([message.mimeType isEqualToString:MIME_TYPE_M4A] || [message.mimeType isEqualToString:MIME_TYPE_IMAGE]) && ![[SDWebImageManager sharedManager] isKeyCached: message.data])) {
                        DDLogVerbose(@"setting message loading");
                        cell.messageStatusLabel.text = NSLocalizedString(@"message_loading_and_decrypting",nil);
                    }
                    else {
                        
                        //   DDLogVerbose(@"setting text for iv: %@ to: %@", [message iv], plainData);
                        DDLogVerbose(@"setting message date");
                        cell.messageStatusLabel.text = message.formattedDate;
                        
                        if (ours) {
                            cell.messageSentView.foregroundColor = [UIColor lightGrayColor];
                        }
                        else {
                            cell.messageSentView.foregroundColor = [UIUtils surespotBlue];
                        }
                    }
                }
            }
            
            if ([message.mimeType isEqualToString:MIME_TYPE_TEXT]) {
                cell.messageLabel.hidden = NO;
                cell.uiImageView.hidden = YES;
                cell.shareableView.hidden = YES;
                cell.audioIcon.hidden = YES;
                cell.audioSlider.hidden = YES;
                cell.messageSize.hidden = YES;
                CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                if (ours) {
                    messageStatusFrame.origin.x = 13;
                }
                else {
                    messageStatusFrame.origin.x = 63;
                }
                cell.messageStatusLabel.frame = messageStatusFrame;
            }
            else {
                if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                    cell.shareableView.hidden = NO;
                    cell.messageLabel.hidden = YES;
                    cell.uiImageView.image = nil;
                    cell.uiImageView.hidden = NO;
                    cell.uiImageView.alignTop = YES;
                    cell.uiImageView.alignLeft = YES;
                    cell.audioIcon.hidden = YES;
                    cell.audioSlider.hidden = YES;
                    if ([message dataSize ] > 0) {
                        cell.messageSize.hidden = NO;
                        cell.messageSize.text = [NSString stringWithFormat:@"%d KB", (int) ceil(message.dataSize/1000.0)];
                    }
                    else {
                        cell.messageSize.hidden = YES;
                    }
                    
                    
                    CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                    if (ours) {
                        messageStatusFrame.origin.x = 22;
                    }
                    else {
                        messageStatusFrame.origin.x = 72;
                    }
                    
                    cell.messageStatusLabel.frame = messageStatusFrame;
                    
                    if (message.shareable) {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_partial_secure"];
                    }
                    else {
                        cell.shareableView.image = [UIImage imageNamed:@"ic_secure"];
                    }
                    
                    [cell setMessage:message
                            progress:^(NSUInteger receivedSize, long long expectedSize) {
                                
                            }
                           completed:^(id data, NSString * mimeType, NSError *error, SDImageCacheType cacheType) {
                               if (error) {
                                   
                               }
                           }
                        retryAttempt:0
                     
                     ];
                    
                    DDLogVerbose(@"imageView: %@", cell.uiImageView);
                }
                else {
                    if ([message.mimeType isEqualToString:MIME_TYPE_M4A]) {
                        CGRect messageStatusFrame = cell.messageStatusLabel.frame;
                        if (ours) {
                            [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_play"]];
                            messageStatusFrame.origin.x = 13;
                        }
                        else {
                            if (message.voicePlayed) {
                                [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_play"]];
                            }
                            else {
                                [cell.audioIcon setImage: [UIImage imageNamed:@"ic_media_played"]];
                            }
                            messageStatusFrame.origin.x = 63;
                            
                        }
                        cell.messageStatusLabel.frame = messageStatusFrame;
                        
                        if ([message dataSize ] > 0) {
                            cell.messageSize.hidden = NO;
                            cell.messageSize.text = [NSString stringWithFormat:@"%d KB", (int) ceil(message.dataSize/1000.0)];
                        }
                        else {
                            cell.messageSize.hidden = YES;
                        }
                        cell.shareableView.hidden = YES;
                        cell.messageLabel.hidden = YES;
                        cell.uiImageView.hidden = YES;
                        cell.audioIcon.hidden = NO;
                        cell.audioSlider.hidden = NO;
                        
                        if (!message.hashed && message.playVoice && [username isEqualToString: [self getCurrentTabName]]) {
                            [self ensureVoiceDelegate];
                            [_voiceDelegate playVoiceMessage:message cell:cell];
                        }
                        else {
                            [cell setMessage:message
                                    progress:^(NSUInteger receivedSize, long long expectedSize) {
                                        
                                    }
                                   completed:^(id data, NSString * mimeType, NSError *error, SDImageCacheType cacheType) {
                                       if (!error) {
                                           
                                       }
                                   }
                                retryAttempt:0
                             ];
                        }
                        
                        [self ensureVoiceDelegate];
                        [_voiceDelegate attachCell:cell];
                    }
                }
            }
            
            DDLogVerbose(@"returning cell, status text %@", cell.messageStatusLabel.text);
            return cell;
        }
        else {
            static NSString *CellIdentifier = @"Cell";
            UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
            cell.backgroundColor = [UIColor clearColor];
            cell.userInteractionEnabled = NO;
            return cell;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger page = [_swipeView indexOfItemViewOrSubview:tableView];
    DDLogVerbose(@"selected, on page: %d", page);
    
    if (page == 0) {
        Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource].friends objectAtIndex:indexPath.row];
        
        if (afriend && [afriend isFriend]) {
            NSString * friendname =[afriend name];
            [self showChat:friendname];
        }
        else {
            [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
        }
    }
    else {
        // if it's an image, open it in image viewer
        ChatDataSource * cds = [[ChatController sharedInstance] getDataSourceForFriendname:[self getCurrentTabName]];
        if (cds) {
            SurespotMessage * message = [cds.messages objectAtIndex:indexPath.row];
        
            //if hashed do nothing
            if (message.hashed) {
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                return;
            }
            
            if ([message.mimeType isEqualToString: MIME_TYPE_IMAGE]) {
                // Create array of `MWPhoto` objects
                _imageMessage = message;
                // Create & present browser
                MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
                // Set options
                browser.displayActionButton = NO; // Show action button to allow sharing, copying, etc (defaults to YES)
                browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
                browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
                browser.wantsFullScreenLayout = NO; // iOS 5 & 6 only: Decide if you want the photo browser full screen, i.e. whether the status bar is affected (defaults to YES)
                
                // Present
                [self.navigationController pushViewController:browser animated:YES];
            }
            else {
                if ([message.mimeType isEqualToString: MIME_TYPE_M4A]) {
                    [self ensureVoiceDelegate];
                    MessageView * cell = (MessageView *) [tableView cellForRowAtIndexPath: indexPath];
                    
                    [_voiceDelegate playVoiceMessage: message cell:cell];
                }
            }
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

-(NSArray *) sortedAliasedChats {
    //account for aliases
    NSArray * allKeys = [_chats allKeys];
    
    NSMutableArray * aliasedChats = [NSMutableArray new];
    for (NSString * username in allKeys) {
        NSString * aliasedName = [[[[ChatController sharedInstance] getHomeDataSource] getFriendByName:username] nameOrAlias];
        UsernameAliasMap * t = [UsernameAliasMap new];
        t.username = username;
        t.alias = aliasedName;
        [aliasedChats addObject:t];
    }
    
    return [aliasedChats sortedArrayUsingComparator:^NSComparisonResult(UsernameAliasMap * obj1, UsernameAliasMap * obj2) {
        return [obj1.alias compare:obj2.alias options:NSCaseInsensitiveSearch];
    }];
}

-(NSArray *) sortedValues {
    NSArray * sortedMaps = [self sortedAliasedChats];
    NSMutableArray * sortedValues = [NSMutableArray new];
    for (UsernameAliasMap * map in sortedMaps) {
        [sortedValues addObject:[_chats objectForKey:map.username]];
    }
    return sortedValues;
}

-(void) loadChat:(NSString *) username show: (BOOL) show  availableId: (NSInteger) availableId availableControlId: (NSInteger) availableControlId {
    DDLogVerbose(@"entered");
    //get existing view if there is one
    UITableView * chatView;
    @synchronized (_chats) {
        chatView = [_chats objectForKey:username];
    }
    if (!chatView) {
        
        chatView = [[UITableView alloc] initWithFrame:_swipeView.frame];
        [chatView setBackgroundColor:[UIColor clearColor]];
        [chatView setDelegate:self];
        [chatView setDataSource: self];
        [chatView setScrollsToTop:NO];
        [chatView setDirectionalLockEnabled:YES];
        [chatView setSeparatorColor: [UIUtils surespotSeparatorGrey]];
        if ([chatView respondsToSelector:@selector(setSeparatorInset:)]) {
            [chatView setSeparatorInset:UIEdgeInsetsZero];
        }
        [self addLongPressGestureRecognizer:chatView];
        
        // setup pull-to-refresh
        __weak UITableView *weakView = chatView;
        [chatView addPullToRefreshWithActionHandler:^{
            
            [[ChatController sharedInstance] loadEarlierMessagesForUsername: username callback:^(id result) {
                if (result) {
                    NSInteger resultValue = [result integerValue];
                    if (resultValue == 0 || resultValue == NSIntegerMax) {
                        [UIUtils showToastKey:@"all_messages_loaded"];
                    }
                    else {
                        DDLogVerbose(@"loaded %@ earlier messages for user: %@", result, username);
                        [self updateTableView:weakView withNewRowCount:[result integerValue]];
                    }
                }
                else {
                    [UIUtils showToastKey:@"loading_earlier_messages_failed"];
                }
                
                [weakView.pullToRefreshView stopAnimating];
                
            }];
        }];
        
        //create the data source
        [[ChatController sharedInstance] createDataSourceForFriendname:username availableId: availableId availableControlId:availableControlId];
        
        NSInteger index = 0;
        @synchronized (_chats) {
            
            [_chats setObject:chatView forKey:username];
            
            
            NSArray * sortedChats = [self sortedAliasedChats];
            for (int i=0;i<[sortedChats count];i++) {
                if ([[sortedChats[i] username] isEqualToString:username])  {
                    index = i+1;
                    break;
                }
            }
        }
        
        DDLogVerbose(@"creatingindex: %d", index);
        
        //   [chatView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"ChatCell"];
        [chatView registerNib:[UINib nibWithNibName:@"OurMessageCell" bundle:nil] forCellReuseIdentifier:@"OurMessageView"];
        [chatView registerNib:[UINib nibWithNibName:@"TheirMessageCell" bundle:nil] forCellReuseIdentifier:@"TheirMessageView"];
        
        [_swipeView loadViewAtIndex:index];
        [_swipeView updateItemSizeAndCount];
        [_swipeView updateScrollViewDimensions];
        
        if (show) {
            _scrollingTo = index;
            [_swipeView scrollToPage:index duration:0.500];
            [[ChatController sharedInstance] setCurrentChat: username];
        }
        
    }
    
    else {
        if (show) {
            [[ChatController sharedInstance] setCurrentChat: username];
            NSInteger index=0;
            @synchronized (_chats) {
                
                NSArray * sortedChats = [self sortedAliasedChats];
                for (int i=0;i<[sortedChats count];i++) {
                    if ([[sortedChats[i] username] isEqualToString:username])  {
                        index = i+1;
                        break;
                    }
                }
            }
            
            DDLogVerbose(@"scrolling to index: %d", index);
            _scrollingTo = index;
            [_swipeView scrollToPage:index duration:0.500];
        }
    }
}

-(void) showChat:(NSString *) username {
    DDLogVerbose(@"showChat, %@", username);
    
    Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:username];
    
    [self loadChat:username show:YES availableId:[afriend availableMessageId] availableControlId:[afriend availableMessageControlId]];
    //   [_textField resignFirstResponder];
}



- (BOOL) handleTextAction {
    return [self handleTextActionResign:YES];
}

- (BOOL) handleTextActionResign: (BOOL) resign {
    if (![self getCurrentTabName]) {
        NSString * text = _inviteTextView.text;
        
        if ([text length] > 0) {
            
            NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
            if ([text isEqualToString:loggedInUser]) {
                [UIUtils showToastKey:@"friend_self_error"];
                return YES;
            }
            
            
            [[ChatController sharedInstance] inviteUser:text];
            [_inviteTextView setText:nil];
            [self updateTabChangeUI];
            return YES;
        }
        else {
            if (resign) {
                [self resignAllResponders];
            }
            return NO;
        }
        
    }
    else {
        NSString * text = _messageTextView.text;
        
        if ([text length] > 0) {
            
            [self send];
            return YES;
        }
        
        else {
            if (resign) {
                [self resignAllResponders];
            }
            return NO;
        }
    }
    
    
}


- (void) send {
    
    NSString* message = _messageTextView.text;
    
    if ([UIUtils stringIsNilOrEmpty:message]) return;
    
    NSString * friendname = [self getCurrentTabName];
    
    Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName: friendname];
    if ([afriend isDeleted]) {
        return;
    }
    
    [[ChatController sharedInstance] sendMessage: message toFriendname:friendname];
    [_messageTextView setText:nil];
    
    [self updateTabChangeUI];
}


//if we're going to chat tab from home tab and keyboard is showing
//become the first esponder so we're not typing in the invite field
//thinking we're typing in the text field
-(void) updateKeyboardState: (BOOL) goingHome {
    DDLogInfo(@"updateKeyboardState, goingHome: %hhd", goingHome);
    if (goingHome) {
        [self resignAllResponders];
    }
    else {
        if ([_inviteTextView isFirstResponder]) {
            if (![UIUtils isIOS8Plus]) {
                [_inviteTextView resignFirstResponder];
            }
            [_messageTextView becomeFirstResponder];
        }
    }
}

-(void) updateTabChangeUI {
    DDLogVerbose(@"updateTabChangeUI");
    if (![self getCurrentTabName]) {
        [_theButton setImage:[UIImage imageNamed:@"ic_menu_invite"] forState:UIControlStateNormal];
        _messageTextView.hidden = YES;
        
        _inviteTextView.hidden = NO;
    }
    else {
        _inviteTextView.hidden = YES;
        Friend *afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
        if (afriend.isDeleted) {
            [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
            _messageTextView.hidden = YES;
        }
        else {
            _messageTextView.hidden = NO;
            if ([_messageTextView.text length] > 0) {
                [_theButton setImage:[UIImage imageNamed:@"ic_menu_send"] forState:UIControlStateNormal];
            }
            else {
                
                BOOL dontAsk = [[NSUserDefaults standardUserDefaults] boolForKey:@"pref_dont_ask"];
                if (dontAsk) {
                    
                    [_theButton setImage:[UIImage imageNamed:@"ic_menu_home"] forState:UIControlStateNormal];
                }
                else {
                    [_theButton setImage:[UIImage imageNamed:@"ic_btn_speak_now"] forState:UIControlStateNormal];
                }
                
            }
        }
    }
}

-(void) updateTableView: (UITableView *) tableView withNewRowCount : (int) rowCount
{
    //Save the tableview content offset
    CGPoint tableViewOffset = [tableView contentOffset];
    
    //compute the height change
    int heightForNewRows = 0;
    
    for (NSInteger i = 0; i < rowCount; i++) {
        NSIndexPath *tempIndexPath = [NSIndexPath indexPathForRow:i inSection:0];
        heightForNewRows += [self tableView:tableView heightForRowAtIndexPath: tempIndexPath];
    }
    
    tableViewOffset.y += heightForNewRows;
    [tableView reloadData];
    [tableView setContentOffset:tableViewOffset animated:NO];
}


- (void)refreshMessages:(NSNotification *)notification {
    NSString * username = [notification.object objectForKey:@"username"];
    BOOL scroll = [[notification.object objectForKey:@"scroll"] boolValue];
    DDLogVerbose(@"username: %@, currentchat: %@, scroll: %hhd", username, [self getCurrentTabName], scroll);
    
    if ([username isEqualToString: [self getCurrentTabName]]) {
        
        UITableView * tableView;
        @synchronized (_chats) {
            tableView = [_chats objectForKey:username];
        }
        
        if (tableView) {
            [tableView reloadData];
            
            if (scroll) {
                @synchronized (_needsScroll) {
                    [_needsScroll removeObjectForKey:username];
                }
                
                [self performSelector:@selector(scrollTableViewToBottom:) withObject:tableView afterDelay:0.5];
            }
        }
    }
    else {
        if (scroll) {
            @synchronized (_needsScroll) {
                DDLogVerbose(@"setting needs scroll for %@", username);
                [_needsScroll setObject:@"yourmama" forKey:username];
                [_bottomIndexPaths removeObjectForKey:username];
            }
        }
    }
}

- (void) scrollTableViewToBottom: (UITableView *) tableView {
    NSInteger numRows =[tableView numberOfRowsInSection:0];
    if (numRows > 0) {
        DDLogVerbose(@"scrolling to row: %d", numRows);
        NSIndexPath *scrollIndexPath = [NSIndexPath indexPathForRow:(numRows - 1) inSection:0];
        if ( [tableView numberOfSections] > scrollIndexPath.section && [tableView numberOfRowsInSection:0] > scrollIndexPath.row ) {
            [tableView scrollToRowAtIndexPath:scrollIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }
}


- (void) scrollTableViewToCell: (UITableView *) tableView  indexPath: (NSIndexPath *) indexPath {
    DDLogVerbose(@"scrolling to cell: %@", indexPath);
    if ( [tableView numberOfSections] > indexPath.section && [tableView numberOfRowsInSection:0] > indexPath.row ) {
        [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
    }
    
}

- (void)refreshHome:(NSNotification *)notification
{
    DDLogVerbose(@"refreshHome");
    
    if (_friendView) {
        [_friendView reloadData];
    }
    
}


-(void) removeFriend: (Friend *) afriend {
    [[[ChatController sharedInstance] getHomeDataSource] removeFriend:afriend withRefresh:YES];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        //strip out commas
        string = [[_dateFormatter stringFromDate:date ] stringByReplacingOccurrencesOfString:@"," withString:@""];
    });
    return string;
}

-(REMenu *) createMenuMenu {
    //menu menu
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    if ([self getCurrentTabName]) {
        Friend * theFriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
        if ([theFriend isFriend] && ![theFriend isDeleted]) {
            NSString * theirUsername = [self getCurrentTabName];
            
            REMenuItem * selectImageItem = [[REMenuItem alloc]
                                            initWithTitle:NSLocalizedString(@"select_image", nil)
                                            image:[UIImage imageNamed:@"ic_menu_gallery"]
                                            highlightedImage:nil
                                            action:^(REMenuItem * item){
                                                
                                                _imageDelegate = [[ImageDelegate alloc]
                                                                  initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                                  ourVersion:[[IdentityController sharedInstance] getOurLatestVersion]
                                                                  theirUsername:theirUsername
                                                                  assetLibrary:_assetLibrary];
                                                
                                                [ImageDelegate startImageSelectControllerFromViewController:self usingDelegate:_imageDelegate];
                                                
                                                
                                            }];
            [menuItems addObject:selectImageItem];
            
            
            REMenuItem * captureImageItem = [[REMenuItem alloc]
                                             initWithTitle:NSLocalizedString(@"capture_image", nil)
                                             image:[UIImage imageNamed:@"ic_menu_camera"]
                                             highlightedImage:nil
                                             action:^(REMenuItem * item){
                                                 
                                                 _imageDelegate = [[ImageDelegate alloc]
                                                                   initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                                   ourVersion:[[IdentityController sharedInstance] getOurLatestVersion]
                                                                   theirUsername:theirUsername
                                                                   assetLibrary:_assetLibrary];
                                                 [ImageDelegate startCameraControllerFromViewController:self usingDelegate:_imageDelegate];
                                                 
                                                 
                                             }];
            [menuItems addObject:captureImageItem];
        }
        
        REMenuItem * closeTabItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
            [self closeTab];
        }];
        
        
        
        [menuItems addObject:closeTabItem];
        
        REMenuItem * deleteAllItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
            //confirm if necessary
            
            BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:[[IdentityController sharedInstance] getLoggedInUser] key:@"_user_pref_delete_all_messages"];
            if (confirm) {
                NSString * okString = NSLocalizedString(@"ok", nil);
                [UIAlertView showWithTitle:NSLocalizedString(@"delete_all_title", nil)
                                   message:NSLocalizedString(@"delete_all_confirmation", nil)
                         cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                         otherButtonTitles:@[okString]
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                      if (buttonIndex == [alertView cancelButtonIndex]) {
                                          DDLogVerbose(@"delete cancelled");
                                      } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                          [[ChatController sharedInstance] deleteMessagesForFriend: [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]]];
                                      };
                                      
                                  }];
            }
            else {
                
                [[ChatController sharedInstance] deleteMessagesForFriend: [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]]];
            }
            
        }];
        
        [menuItems addObject:deleteAllItem];
    }
    
    REMenuItem * shareItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"share_invite_link", nil) image:[UIImage imageNamed:@"blue_heart"] highlightedImage:nil action:^(REMenuItem * menuitem){
        
        _progressView = [LoadingView showViewKey:@"invite_progress_text"];
        NSString * inviteUrl = [NSString stringWithFormat:@"%@%@%@", @"https://server.surespot.me/autoinvite/", [[[IdentityController sharedInstance] getLoggedInUser] stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], @"/ios"];
        
        
        [[NetworkController sharedInstance] getShortUrl:inviteUrl callback:^(id shortUrl) {
            [_progressView removeView];
            NSString * text = [NSString stringWithFormat:NSLocalizedString(@"external_invite_message", nil), shortUrl];
            
            UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
            
            controller.excludedActivityTypes = @[UIActivityTypePostToWeibo,
                                                 UIActivityTypePrint,
                                                 UIActivityTypeAssignToContact,
                                                 UIActivityTypeSaveToCameraRoll,
                                                 UIActivityTypeAddToReadingList,
                                                 UIActivityTypePostToFlickr,
                                                 UIActivityTypePostToVimeo,
                                                 UIActivityTypePostToTencentWeibo,
                                                 UIActivityTypeAirDrop];
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            {
                [self presentViewController:controller animated:YES completion:nil];
            }
            //if iPad
            else
            {
                // Change Rect to position Popover
                _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
                _popover.delegate = self;
                [_popover presentPopoverFromRect:CGRectMake(self.view.frame.size.width/2, self.view.frame.size.height/2, 0, 0) inView:self.view permittedArrowDirections:0 animated:YES];
            }
        }];
    }];
    [menuItems addObject:shareItem];
    
    
    
    REMenuItem * pwylItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"pay_what_you_like", nil) image:
                             [UIImage imageNamed:@"heart"]
                                             highlightedImage:nil action:^(REMenuItem * item){
                                                 [[PurchaseDelegate sharedInstance] showPwylViewForController:self];
                                                 
                                                 
                                             }];
    [menuItems addObject:pwylItem];
    
    if (![[PurchaseDelegate sharedInstance] hasVoiceMessaging]) {
        REMenuItem * purchaseVoiceItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_purchase_voice_messaging", nil) image:
                                          [UIImage imageNamed:@"gold_heart"]
                                                          highlightedImage:nil action:^(REMenuItem * item){
                                                              [[PurchaseDelegate sharedInstance] showPurchaseVoiceViewForController:self];
                                                              
                                                              
                                                          }];
        [menuItems addObject:purchaseVoiceItem];
    }
    
    REMenuItem * settingsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"settings", nil) image:[UIImage imageNamed:@"ic_menu_preferences"] highlightedImage:nil action:^(REMenuItem * item){
        [self showSettings];
        
    }];
    
    [menuItems addObject:settingsItem];
    
    REMenuItem * logoutItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"logout", nil) image:[UIImage imageNamed:@"ic_lock_power_off"] highlightedImage:nil action:^(REMenuItem * item){
        [self logout];
        
    }];
    [menuItems addObject:logoutItem];
    
    return [self createMenu: menuItems];
}

-(REMenu *) createMenu: (NSArray *) menuItems {
    return [UIUtils createMenu:menuItems closeCompletionHandler:^{
        _menu = nil;
        NSString * getCurrentChat = [self getCurrentTabName];
        if (getCurrentChat) {
            id currentTableView =[_chats objectForKey:getCurrentChat];
            if (currentTableView ) {
                [currentTableView deselectRowAtIndexPath:[currentTableView indexPathForSelectedRow] animated:YES];
            }
        }
        else {
            [_friendView deselectRowAtIndexPath:[_friendView indexPathForSelectedRow] animated:YES];
        }
        _swipeView.userInteractionEnabled = YES;
        [self updateTabChangeUI];
    }];
}


-(REMenu *) createHomeMenuFriend: (Friend *) thefriend {
    //home menu
    NSMutableArray * menuItems = [NSMutableArray new];
    UsernameAliasMap * map = [UsernameAliasMap new];
    map.username = thefriend.name;
    map.alias = thefriend.aliasPlain;
    
    
    NSString * aliasName =[UIUtils buildAliasStringForUsername:[thefriend name] alias:[thefriend aliasPlain]];
    REMenuItem * titleItem = [[REMenuItem alloc] initWithTitle: nil image:nil highlightedImage:nil action:nil];
    
    [titleItem setSubtitle:aliasName];
    [titleItem setTitleEnabled:NO];
    
    [menuItems addObject:titleItem];
    
    if ([thefriend isFriend]) {
        
        
        if ([thefriend isChatActive]) {
            REMenuItem * closeTabHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_close_tab", nil) image:[UIImage imageNamed:@"ic_menu_end_conversation"] highlightedImage:nil action:^(REMenuItem * item){
                [self closeTabName: thefriend.name];
            }];
            [menuItems addObject:closeTabHomeItem];
        }
        
        
        REMenuItem * deleteAllHomeItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_all_messages", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
            
            //confirm if necessary
            BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:[[IdentityController sharedInstance] getLoggedInUser] key:@"_user_pref_delete_all_messages"];
            if (confirm) {
                NSString * okString = NSLocalizedString(@"ok", nil);
                [UIAlertView showWithTitle:NSLocalizedString(@"delete_all_title", nil)
                                   message:NSLocalizedString(@"delete_all_confirmation", nil)
                         cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                         otherButtonTitles:@[okString]
                                  tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                      if (buttonIndex == [alertView cancelButtonIndex]) {
                                          DDLogVerbose(@"delete cancelled");
                                      } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                          [[ChatController sharedInstance] deleteMessagesForFriend: thefriend];
                                      };
                                      
                                  }];
            }
            else {
                [[ChatController sharedInstance] deleteMessagesForFriend: thefriend];
            }
        }];
        [menuItems addObject:deleteAllHomeItem];
        
        
        if (![thefriend isDeleted]) {
            REMenuItem * fingerprintsItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"verify_key_fingerprints", nil) image:[UIImage imageNamed:@"fingerprint_zoom"] highlightedImage:nil action:^(REMenuItem * item){
                //cameraUI
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                    _popover = [[UIPopoverController alloc] initWithContentViewController:[[KeyFingerprintViewController alloc]                                                                                                            initWithNibName:@"KeyFingerprintView" username:map]];
                    _popover.delegate = self;
                    CGFloat x = self.view.bounds.size.width;
                    CGFloat y =self.view.bounds.size.height;
                    DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
                    [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:YES];
                    [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
                    
                } else {
                    
                    
                    [self.navigationController pushViewController:[[KeyFingerprintViewController alloc] initWithNibName:@"KeyFingerprintView" username:map] animated:YES];
                }
                
            }];
            [menuItems addObject:fingerprintsItem];
            
            
            if (![thefriend hasFriendImageAssigned]) {
                REMenuItem * selectImageItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_assign_image", nil)
                                                image:[UIImage imageNamed:@"ic_menu_gallery"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    
                                                    _imageDelegate = [[ImageDelegate alloc]
                                                                      initWithUsername:[[IdentityController sharedInstance] getLoggedInUser]
                                                                      ourVersion:[[IdentityController sharedInstance] getOurLatestVersion]
                                                                      theirUsername:thefriend.name
                                                                      assetLibrary:nil];
                                                    
                                                    [ImageDelegate startFriendImageSelectControllerFromViewController:self usingDelegate:_imageDelegate];
                                                    
                                                    
                                                }];
                [menuItems addObject:selectImageItem];
            }
            else {
                REMenuItem * removeImageItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_remove_friend_image", nil)
                                                image:[UIImage imageNamed:@"ic_menu_gallery"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    [[ChatController sharedInstance] removeFriendImage:[thefriend name] callbackBlock:^(id result) {
                                                        BOOL success = [result boolValue];
                                                        if (!success) {
                                                            [UIUtils showToastKey:@"could_not_remove_friend_image" duration:1];
                                                        }
                                                    }];
                                                    
                                                    
                                                }];
                [menuItems addObject:removeImageItem];
                
            }
            
            if (![thefriend hasFriendAliasAssigned]) {
                REMenuItem * assignAliasItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_assign_alias", nil)
                                                image:[UIImage imageNamed:@"ic_menu_friendslist"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    
                                                    //show alert view to get password
                                                    UIAlertView * av = [[UIAlertView alloc]
                                                                        initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"enter_alias", nil), [thefriend name]]
                                                                        message:[NSString stringWithFormat:NSLocalizedString(@"enter_alias_for", nil), [thefriend name]]
                                                                        delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                                                                        otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
                                                    av.alertViewStyle = UIAlertViewStylePlainTextInput;
                                                    av.shouldEnableFirstOtherButtonBlock = ^BOOL(UIAlertView * alertView) {
                                                        return ([[[alertView textFieldAtIndex:0] text] length] <= 20);
                                                    };
                                                    av.tapBlock =^(UIAlertView *alertView, NSInteger buttonIndex) {
                                                        if (buttonIndex == alertView.firstOtherButtonIndex) {
                                                            NSString * alias = [[alertView textFieldAtIndex:0] text];
                                                            if (![UIUtils stringIsNilOrEmpty:alias]) {
                                                                DDLogVerbose(@"entered alias: %@", alias);
                                                                [[ChatController sharedInstance] assignFriendAlias:alias toFriendName:[thefriend name] callbackBlock:^(id result) {
                                                                    BOOL success = [result boolValue];
                                                                    if (!success) {
                                                                        [UIUtils showToastKey:@"could_not_assign_friend_alias" duration:1];
                                                                    }
                                                                }];
                                                            }
                                                        }
                                                    };
                                                    
                                                    [[av textFieldAtIndex:0] setText:[thefriend name]];
                                                    [av show];
                                                }];
                [menuItems addObject:assignAliasItem];
            }
            else {
                REMenuItem * removeAliasItem = [[REMenuItem alloc]
                                                initWithTitle:NSLocalizedString(@"menu_remove_friend_alias", nil)
                                                image:[UIImage imageNamed:@"ic_menu_friendslist"]
                                                highlightedImage:nil
                                                action:^(REMenuItem * item){
                                                    [[ChatController sharedInstance] removeFriendAlias:[thefriend name] callbackBlock:^(id result) {
                                                        BOOL success = [result boolValue];
                                                        if (!success) {
                                                            [UIUtils showToastKey:@"could_not_remove_friend_alias" duration:1];
                                                        }
                                                    }];
                                                }];
                [menuItems addObject:removeAliasItem];
            }
        }
    }
    
    if (![thefriend isInviter]) {
        
        REMenuItem * deleteFriendItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_friend", nil) image:[UIImage imageNamed:@"ic_menu_blocked_user"] highlightedImage:nil action:^(REMenuItem * item){
            
            NSString * okString = NSLocalizedString(@"ok", nil);
            [UIAlertView showWithTitle:NSLocalizedString(@"menu_delete_friend", nil)
                               message:[NSString stringWithFormat: NSLocalizedString(@"delete_friend_confirmation", nil), [UIUtils buildAliasStringForUsername:thefriend.name alias:thefriend.aliasPlain]]
                     cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                     otherButtonTitles:@[okString]
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  if (buttonIndex == [alertView cancelButtonIndex]) {
                                      DDLogVerbose(@"delete cancelled");
                                  } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                      [[ChatController sharedInstance] deleteFriend: thefriend];
                                  };
                              }];
            
            
            
        }];
        [menuItems addObject:deleteFriendItem];
    }
    
    
    return [self createMenu: menuItems];
}

-(REMenu *) createChatMenuMessage: (SurespotMessage *) message {
    BOOL ours = [ChatUtils isOurMessage:message];
    NSMutableArray * menuItems = [NSMutableArray new];
    
    //copy
    if ([message.mimeType isEqualToString:MIME_TYPE_TEXT] && message.plainData) {
        REMenuItem * copyItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_copy", nil) image:[UIImage imageNamed:@"ic_menu_copy"] highlightedImage:nil action:^(REMenuItem * item){
            
            [[UIPasteboard generalPasteboard]  setString: message.plainData];
            
            //            [UIUtils showToastKey:@"message" duration:2];
            
        }];
        [menuItems addObject:copyItem];
        
    }
    
    if ([message.mimeType isEqualToString:MIME_TYPE_IMAGE]) {
        if (message.errorStatus > 0 && ours) {
            UIImage * image = nil;
            NSString * title = nil;
            
            title = NSLocalizedString(@"menu_resend_message", nil);
            image = [UIImage imageNamed:@"ic_menu_send"];
            
            REMenuItem * resendItem = [[REMenuItem alloc] initWithTitle:title image:image highlightedImage:nil action:^(REMenuItem * item){
                [[ChatController sharedInstance] resendFileMessage:message];
            }];
            
            [menuItems addObject:resendItem];
        }
        
        //if i'ts our message and ti's been sent we can change lock status
        if (message.serverid > 0 && ours) {
            UIImage * image = nil;
            NSString * title = nil;
            if (!message.shareable) {
                title = NSLocalizedString(@"menu_unlock", nil);
                image = [UIImage imageNamed:@"ic_menu_partial_secure"];
            }
            else {
                title = NSLocalizedString(@"menu_lock", nil);
                image = [UIImage imageNamed:@"ic_menu_secure"];
            }
            
            REMenuItem * shareItem = [[REMenuItem alloc] initWithTitle:title image:image highlightedImage:nil action:^(REMenuItem * item){
                [[ChatController sharedInstance] toggleMessageShareable:message];
                
            }];
            
            [menuItems addObject:shareItem];
        }
        
        //allow saving to gallery if it's unlocked, or it's ours
        if (message.shareable && !ours) {
            REMenuItem * saveItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"save_to_photos", nil) image:[UIImage imageNamed:@"ic_menu_save"] highlightedImage:nil action:^(REMenuItem * item){
                if (message.shareable && !ours) {
                    [SDWebImageManager.sharedManager downloadWithURL: [NSURL URLWithString:message.data]
                                                            mimeType: MIME_TYPE_IMAGE
                                                          ourVersion: [message getOurVersion]
                                                       theirUsername: [message getOtherUser]
                                                        theirVersion: [message getTheirVersion]
                                                                  iv: [message iv]
                                                             options: (SDWebImageOptions) 0
                                                            progress:nil completed:^(id data, NSString * mimeType, NSError *error, SDImageCacheType cacheType, BOOL finished)
                     {
                         if (error) {
                             [UIUtils showToastKey:@"error_saving_image_to_photos"];
                         }
                         else {
                             [_assetLibrary saveImage:data toAlbum:@"surespot" withCompletionBlock:^(NSError *error, NSURL * url) {
                                 if (error) {
                                     [UIUtils showToastKey:@"error_saving_image_to_photos" duration:2];
                                 }
                                 else {
                                     [UIUtils showToastKey:@"image_saved_to_photos"];
                                 }
                             }];
                         }
                     }];
                }
                else {
                    [UIUtils showToastKey:@"error_saving_image_to_photos_locked" duration:2];
                }
            }];
            [menuItems addObject:saveItem];
        }
    }
    
    else {
        if ([message.mimeType isEqualToString:MIME_TYPE_M4A]) {
            
            if (![[PurchaseDelegate sharedInstance] hasVoiceMessaging]) {
                REMenuItem * purchaseVoiceItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_purchase_voice_messaging", nil) image:
                                                  [UIImage imageNamed:@"gold_heart"]
                                                                  highlightedImage:nil action:^(REMenuItem * item){
                                                                      [[PurchaseDelegate sharedInstance] showPurchaseVoiceViewForController:self];
                                                                      
                                                                      
                                                                  }];
                [menuItems addObject:purchaseVoiceItem];
            }
            
            if (message.errorStatus > 0 && ours) {
                UIImage * image = nil;
                NSString * title = nil;
                
                title = NSLocalizedString(@"menu_resend_message", nil);
                image = [UIImage imageNamed:@"ic_menu_send"];
                
                REMenuItem * resendItem = [[REMenuItem alloc] initWithTitle:title image:image highlightedImage:nil action:^(REMenuItem * item){
                    [[ChatController sharedInstance] resendFileMessage:message];
                }];
                
                [menuItems addObject:resendItem];
            }
        }
    }
    
    
    
    //can always delete
    REMenuItem * deleteItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"menu_delete_message", nil) image:[UIImage imageNamed:@"ic_menu_delete"] highlightedImage:nil action:^(REMenuItem * item){
        
        //confirm if necessary
        BOOL confirm = [UIUtils getBoolPrefWithDefaultYesForUser:[[IdentityController sharedInstance] getLoggedInUser] key:@"_user_pref_delete_message"];
        if (confirm) {
            NSString * okString = NSLocalizedString(@"ok", nil);
            [UIAlertView showWithTitle:NSLocalizedString(@"delete_message", nil)
                               message:NSLocalizedString(@"delete_message_confirmation_title", nil)
                     cancelButtonTitle:NSLocalizedString(@"cancel", nil)
                     otherButtonTitles:@[okString]
                              tapBlock:^(UIAlertView *alertView, NSInteger buttonIndex) {
                                  if (buttonIndex == [alertView cancelButtonIndex]) {
                                      DDLogVerbose(@"delete cancelled");
                                  } else if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:okString]) {
                                      [self deleteMessage: message];
                                  };
                                  
                              }];
        }
        else {
            
            [self deleteMessage: message];
        }
        
        
    }];
    
    [menuItems addObject:deleteItem];
    return [self createMenu: menuItems];
    
}

-(void)tableLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    NSInteger _menuPage = _swipeView.currentPage;
    UITableView * currentView = _menuPage == 0 ? _friendView : [[self sortedValues] objectAtIndex:_menuPage-1];
    
    CGPoint p = [gestureRecognizer locationInView:currentView];
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        
        NSIndexPath *indexPath = [currentView indexPathForRowAtPoint:p];
        if (indexPath == nil) {
            DDLogVerbose(@"long press on table view at page %d but not on a row", _menuPage);
        }
        else {
            
            
            [currentView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
            [self showMenuForPage: _menuPage indexPath: indexPath];
            DDLogVerbose(@"long press on table view at page %d, row %d", _menuPage, indexPath.row);
        }
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        DDLogVerbose(@"taking action for chat iv: %@, plaindata: %@", message.iv, message.plainData);
        [[ChatController sharedInstance] deleteMessage: message];
    }
}

-(void) showMenuMenu {
    if (!_menu) {
        _menu = [self createMenuMenu];
        if (_menu) {
            [self resignAllResponders];
            [_menu showSensiblyInView:self.view];
            _swipeView.userInteractionEnabled = NO;
        }
    }
    else {
        [_menu close];
    }
}

-(void) showMenuForPage: (NSInteger) page indexPath: (NSIndexPath *) indexPath {
    if (!_menu) {
        
        if (page == 0) {
            NSArray * friends = [[ChatController sharedInstance] getHomeDataSource].friends;
            if (indexPath.row < [friends count]) {
                Friend * afriend = [friends objectAtIndex:indexPath.row];
                _menu = [self createHomeMenuFriend:afriend];
            }
        }
        
        else {
            NSString * name = [self nameForPage:page];
            NSArray * messages =[[ChatController sharedInstance] getDataSourceForFriendname: name].messages;
            if (indexPath.row < messages.count) {
                SurespotMessage * message =[messages objectAtIndex:indexPath.row];
                _menu = [self createChatMenuMessage:message];
            }
        }
        
        if (_menu) {
            [self resignAllResponders];
            _swipeView.userInteractionEnabled = NO;
            [_menu showSensiblyInView:self.view];
        }
    }
    else {
        [_menu close];
    }
    
}

- (void)deleteFriend:(NSNotification *)notification
{
    NSArray * data =  notification.object;
    
    NSString * name  =[data objectAtIndex:0];
    BOOL ideleted = [[data objectAtIndex:1] boolValue];
    
    if (ideleted) {
        [self closeTabName:name];
    }
    else {
        [self updateTabChangeUI];
        if ([name isEqualToString:[self getCurrentTabName]]) {
            [_messageTextView resignFirstResponder];
        }
    }
}

-(void) closeTabName: (NSString *) name {
    if (name) {
        NSInteger page = [_swipeView currentPage];
        DDLogVerbose(@"page before close: %d", page);
        
        [[ChatController sharedInstance] destroyDataSourceForFriendname: name];
        [[[[ChatController sharedInstance] getHomeDataSource] getFriendByName:name] setChatActive:NO];
        @synchronized (_chats) {
            [_chats removeObjectForKey:name];
        }
        [_swipeView reloadData];
        page = [_swipeView currentPage];
        
        if (page >= _swipeView.numberOfPages) {
            page = _swipeView.numberOfPages - 1;
        }
        [_swipeView scrollToPage:page duration:0.2];
        
        DDLogVerbose(@"page after close: %d", page);
        NSString * name = [self nameForPage:page];
        DDLogVerbose(@"name after close: %@", name);
        [[[ChatController sharedInstance] getHomeDataSource] setCurrentChat:name];
        [[[ChatController sharedInstance] getHomeDataSource] postRefresh];
        
    }
}

-(void) closeTab {
    [self closeTabName: [self getCurrentTabName]];
}

-(void) logout {
    DDLogVerbose(@"logout");
    
    //blow the views away
    
    _friendView = nil;
    
    
    
    [[NetworkController sharedInstance] logout];
    [[ChatController sharedInstance] logout];
    [[IdentityController sharedInstance] logout];
    @synchronized (_chats) {
        [_chats removeAllObjects];
        // [_swipeView reloadData];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    
    //could be logging out as a result of deleting the logged in identity, which could be the only identity
    //if this is the case we want to go to the signup screen not the login screen
    //make it like a pop by inserting view controller into stack and popping
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
    UIViewController * viewController;
    
    if ([[[IdentityController sharedInstance] getIdentityNames ] count] == 0 ) {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"signupViewController"];
    }
    else {
        viewController = [storyboard instantiateViewControllerWithIdentifier:@"loginViewController"];
    }
    
    viewController = [storyboard instantiateViewControllerWithIdentifier:@"WelcomeViewController"];
    
    NSArray *vcs =  @[viewController, self];
    [self.navigationController setViewControllers:vcs animated:NO];
    [self.navigationController popViewControllerAnimated:YES];
    
    
    [_swipeView removeFromSuperview];
    _swipeView = nil;
    
    
}



-(void) ensureVoiceDelegate {
    
    if (!_voiceDelegate) {
        _voiceDelegate = [[VoiceDelegate alloc] initWithUsername:[[IdentityController sharedInstance] getLoggedInUser] ourVersion:[[IdentityController sharedInstance] getOurLatestVersion ]];
    }
}


- (IBAction)buttonTouchUpInside:(id)sender {
    DDLogVerbose(@"touch up inside");
    [_buttonTimer invalidate];
    
    NSTimeInterval interval = -[_buttonDownDate timeIntervalSinceNow];
    Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
    
    if (interval < voiceRecordDelay) {
        
        if (![self handleTextActionResign:NO]) {
            BOOL dontAsk = [[NSUserDefaults standardUserDefaults] boolForKey:@"pref_dont_ask"];
            if (dontAsk || [[PurchaseDelegate sharedInstance] hasVoiceMessaging] || afriend.isDeleted) {
                [self resignAllResponders];
                [self scrollHome];
                
            }
            else {
                [[PurchaseDelegate sharedInstance] showPurchaseVoiceViewForController:self];
            }
        }
    }
    else {
        if ([_voiceDelegate isRecording]) {
            [_voiceDelegate stopRecordingSend:[NSNumber numberWithBool:YES]];
        }
    }
}



- (IBAction)buttonTouchDown:(id)sender {
    _buttonDownDate = [NSDate date];
    DDLogVerbose(@"touch down at %@", _buttonDownDate);
    
    //kick off timer
    [_buttonTimer invalidate];
    _buttonTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(buttonTimerFire:) userInfo:[self getCurrentTabName] repeats:NO];
    
}

- (IBAction)buttonTouchUpOutside:(id)sender {
    DDLogVerbose(@"touch up outside");
    
    [_buttonTimer invalidate];
    NSTimeInterval interval = -[_buttonDownDate timeIntervalSinceNow];
    
    
    
    if ([_voiceDelegate isRecording]) {
        
        if (interval > voiceRecordDelay) {
            [_voiceDelegate stopRecordingSend: [NSNumber numberWithBool:NO]];
            [UIUtils showToastKey:@"recording_cancelled"];
            [self updateTabChangeUI];
            return;
        }
        
    }
}

-(void) buttonTimerFire:(NSTimer *) timer {
    
    Friend * afriend = [[[ChatController sharedInstance] getHomeDataSource] getFriendByName:[self getCurrentTabName]];
    
    if (afriend) {
        if (afriend.isDeleted) {
            [self closeTab];
        }
        else {
            if (![self handleTextActionResign:NO]) {
                if ([[PurchaseDelegate sharedInstance  ] hasVoiceMessaging]) {
                    [self ensureVoiceDelegate];
                    [_voiceDelegate startRecordingUsername: afriend.name];
                }
                else {
                    BOOL dontAsk = [[NSUserDefaults standardUserDefaults] boolForKey:@"pref_dont_ask"];
                    if (dontAsk) {
                        [self closeTab];
                    }
                    else {
                        [[PurchaseDelegate sharedInstance] showPurchaseVoiceViewForController:self];
                    }
                }
                
            }
        }
    }
}

- (void) backPressed {
    [self scrollHome];
}

-(void) scrollHome {
    if (_swipeView.currentPage != 0) {
        _scrollingTo = 0;
        [_swipeView scrollToPage:0 duration:0.5];
    }
}

- (void) startProgress: (NSNotification *) notification {
    
    if (_progressCount++ == 0) {
        [UIUtils startSpinAnimation: _backImageView];
    }
    
    DDLogVerbose(@"progress count:%d", _progressCount);
}

-(void) stopProgress: (NSNotification *) notification {
    if (--_progressCount == 0) {
        [UIUtils stopSpinAnimation:_backImageView];
    }
    DDLogVerbose(@"progress count:%d", _progressCount);
}




-(void) unauthorized: (NSNotification *) notification {
    DDLogVerbose(@"unauthorized");
    // [UIUtils showToastKey:@"unauthorized" duration:2];
    [self logout];
}

-(void) newMessage: (NSNotification *) notification {
    SurespotMessage * message = notification.object;
    NSString * currentChat =[self getCurrentTabName];
    //pulse if we're logged in as the user
    if (currentChat &&
        ![message.from isEqualToString: currentChat] &&
        [[[IdentityController sharedInstance] getIdentityNames] containsObject:message.to]) {
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}

-(void) invite: (NSNotification *) notification {
    Friend * thefriend = notification.object;
    NSString * currentChat = [self getCurrentTabName];
    //show toast if we're not on the tab or home page, and pulse if we're logged in as the user
    if (currentChat) {
        [UIUtils showToastMessage:[NSString stringWithFormat:NSLocalizedString(@"notification_invite", nil), [[IdentityController sharedInstance] getLoggedInUser], thefriend.nameOrAlias] duration:1];
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}


-(void) inviteAccepted: (NSNotification *) notification {
    //NSString * acceptedBy = notification.object;
    NSString * currentChat = [self getCurrentTabName];
    // pulse if we're logged in as the user
    if (currentChat) {
        
        [UIUtils startPulseAnimation:_backImageView];
    }
}


#pragma mark -
#pragma mark IASKAppSettingsViewControllerDelegate protocol
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    //[self dismissModalViewControllerAnimated:YES];
    
    // your code here to reconfigure the app for changed settings
    [self setBackgroundImageController:sender];
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    DDLogVerbose(@"setting tapped %@", specifier.key);
    
    if ([specifier.key isEqualToString:@"_user_assign_background_image_key"]) {
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        NSString * key = [NSString stringWithFormat:@"%@%@", [[IdentityController sharedInstance] getLoggedInUser], @"_background_image_url"];
        NSURL * bgImageUrl = [defaults URLForKey:key];
        
        if (bgImageUrl) {
            NSString * assignString = NSLocalizedString(@"pref_title_background_image_select", nil);
            //set preference string
            [defaults setObject:assignString forKey:[ [[IdentityController sharedInstance] getLoggedInUser] stringByAppendingString:specifier.key]];
            //remove image url from defaults
            [defaults removeObjectForKey:key];
            //delete image file from disk
            [[NSFileManager defaultManager] removeItemAtURL:bgImageUrl error:nil];
            [sender.tableView reloadData];
        }
        else {
            //select and assign image
            _imageDelegate = [[ImageDelegate alloc]
                              initWithUsername:nil
                              ourVersion:nil
                              theirUsername:nil
                              assetLibrary:_assetLibrary];
            [ImageDelegate startBackgroundImageSelectControllerFromViewController:sender usingDelegate:_imageDelegate];
        }
        return;
    }
}



-(void) showSettings {
    self.appSettingsViewController.showDoneButton = NO;
    [self.navigationController pushViewController:self.appSettingsViewController animated:YES];
}


- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return 1;
}

- (SurespotPhoto *)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index == 0 && _imageMessage)
        return [[SurespotPhoto alloc] initWithURL:[NSURL URLWithString:_imageMessage.data] encryptionParams:[[EncryptionParams alloc] initWithOurUsername:nil ourVersion:[_imageMessage getOurVersion] theirUsername: [_imageMessage getOtherUser] theirVersion:[_imageMessage getTheirVersion] iv:_imageMessage.iv]];
    return nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    //if we're showing TOS don't let them dismiss
    if ([popoverController.contentViewController class] == [HelpViewController class]) {
        BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
        return tosClicked;
    }
    else {
        return YES;
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}
- (IBAction)qrTouch:(id)sender {
    QRInviteViewController * controller = [[QRInviteViewController alloc] initWithNibName:@"QRInviteView" username: [[IdentityController sharedInstance] getLoggedInUser]];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogVerbose(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 370) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self.navigationController pushViewController:controller animated:YES];
    }
}

-(void) resignAllResponders {
    [_messageTextView resignFirstResponder];
    [_inviteTextView resignFirstResponder];
}


-(void) purchaseStatusChanged: (NSNotification *) notification {
    [self updateTabChangeUI];
}

-(void) backgroundImageChanged: (NSNotification *) notification {
    IASKAppSettingsViewController * controller = notification.object;
    [self setBackgroundImageController: controller];
}

-(void) setBackgroundImageController: (IASKAppSettingsViewController *) controller {
    NSUserDefaults  * defaults = [NSUserDefaults standardUserDefaults];
    NSString * username = [[IdentityController sharedInstance] getLoggedInUser];
    NSURL * url = [defaults URLForKey:[NSString stringWithFormat:@"%@%@",username, @"_background_image_url"]];
    if (url) {
        _hasBackgroundImage = YES;
        _bgImageView.contentMode = UIViewContentModeScaleAspectFill;
        [_bgImageView setImage:[UIImage imageWithData:[NSData dataWithContentsOfURL:url]]];
        [_bgImageView setAlpha: 0.5f];
    }
    else {
        _hasBackgroundImage = NO;
        _bgImageView.image = nil;
    }
    
    [controller.tableView reloadData];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setBackgroundImageController: nil];
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label
   didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


- (void)attributedLabel:(TTTAttributedLabel *)label
didSelectLinkWithPhoneNumber:(NSString *)phoneNumber {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: [NSString stringWithFormat:@"tel://%@", phoneNumber]]];
}

-(void) setTextBoxHints {
    NSInteger tbHintCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"tbHintCount"];
    if (tbHintCount++ < 6) {
        [_inviteTextView setPlaceholder:NSLocalizedString(@"invite_hint", nil)];
        [_messageTextView setPlaceholder:NSLocalizedString(@"message_hint", nil)];
    }
    [[NSUserDefaults standardUserDefaults] setInteger:tbHintCount forKey:@"tbHintCount"];
}


-(void) handleNotification {
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    DDLogVerbose(@"handleNotification, defaults: %@", defaults);
    //if we entered app via notification defaults will be set
    NSString * notificationType = [defaults objectForKey:@"notificationType"];
    NSString * to = [defaults objectForKey:@"notificationTo"];
    if ([notificationType isEqualToString:@"message"]) {
        NSString * from = [defaults objectForKey:@"notificationFrom"];
        if ([to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]]) {
            [self showChat:from];
        }
    }
    else {
        if ([notificationType isEqualToString:@"invite"]) {
            if ([to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]]) {
                [self scrollHome];
            }
        }
    }
    
    [defaults removeObjectForKey:@"notificationType"];
    [defaults removeObjectForKey:@"notificationTo"];
    [defaults removeObjectForKey:@"notificationFrom"];
}

-(void) userSwitch {
    DDLogVerbose(@"userSwitch");
    @synchronized (_chats) {
        [_chats removeAllObjects];
        // [_swipeView reloadData];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_swipeView removeFromSuperview];
    [self resignAllResponders];
    _swipeView = nil;
    
}

-(void) reloadSwipeViewData {
    [_swipeView reloadData];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self resignAllResponders];
}

- (NSString *) getCurrentTabName
{
    if ([_swipeView currentItemIndex] == 0) {
        return nil;
    }
    
    if ([_chats count] == 0) {
        return nil;
    }
    
    
    UsernameAliasMap * aliasMap;
    @synchronized (_chats) {
        NSArray *keys = [self sortedAliasedChats];
        NSInteger index = [_swipeView currentItemIndex];
        if (index > [keys count]) {
            index = [keys count];
        }
        
        index -= 1;
        
        aliasMap = [keys objectAtIndex: index];
    }
    
    return [aliasMap username];
}



@end