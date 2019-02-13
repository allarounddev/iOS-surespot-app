//
//  RestoreIdentityViewController.m
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "RestoreIdentityDocumentsViewController.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "IdentityCell.h"
#import "IdentityController.h"
#import "FileController.h"
#import "UIUtils.h"
#import "LoadingView.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif



@interface RestoreIdentityDocumentsViewController ()
@property (strong, nonatomic) IBOutlet UITableView *tvDocuments;
@property (strong) NSMutableArray * documentsIdentities;
@property (strong) NSDateFormatter * dateFormatter;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (atomic, strong) NSString * file;
@property (atomic, strong) NSString * storedPassword;
@property (strong, nonatomic) IBOutlet UILabel *labelDocumentsRestore;

@end

@implementation RestoreIdentityDocumentsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.translucent = NO;
    self.navigationController.tabBarController.tabBar.translucent = NO;

    if ([self respondsToSelector:@selector(edgesForExtendedLayout)])
    {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    _documentsIdentities = [NSMutableArray new];
    
    
    [self loadIdentities];
    
    [_tvDocuments registerNib:[UINib nibWithNibName:@"IdentityCell" bundle:nil] forCellReuseIdentifier:@"IdentityCell"];
    
    _dateFormatter = [[NSDateFormatter alloc]init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    _labelDocumentsRestore.text = NSLocalizedString(@"restore_from_documents", nil);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



-(void) loadIdentities {
    
    [_documentsIdentities removeAllObjects];
    [_documentsIdentities addObjectsFromArray:[[self getDocumentsIdentityNames] sortedArrayUsingComparator:^(id obj1, id obj2) {
        NSDate *d1 = [obj1 objectForKey:@"date"];
        NSDate *d2 = [obj2 objectForKey:@"date"];
        return [d2 compare:d1];
    }]];
    [_tvDocuments reloadData];
    
    
}

- (NSArray *) getDocumentsIdentityNames {
    
    NSString * identityDir = [FileController getDocumentsDir];
    NSArray * dirfiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:identityDir error:NULL];
    
    NSMutableArray * identityFiles = [NSMutableArray new];

    
    NSString * file;
    for (file in dirfiles) {
        NSString * name = [[IdentityController sharedInstance] identityNameFromFile: file] ;
        
        if (name) {
            NSMutableDictionary * identityFile = [NSMutableDictionary new];
            [identityFile  setObject: name forKey:@"name"];
            
            NSString * path =[identityDir stringByAppendingPathComponent:file];
            NSDictionary *filePathsArray1 = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            
            [identityFile setObject:[filePathsArray1 objectForKey:NSFileModificationDate] forKey:@"date"];
            [identityFile setObject:path forKey:@"filename"];
            [identityFiles addObject:identityFile];
        }        
    }
    
    return identityFiles;
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _documentsIdentities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"IdentityCell";
    
    IdentityCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    NSDictionary *file = [self.documentsIdentities objectAtIndex:indexPath.row];
    cell.nameLabel.text = [file objectForKey:@"name"];
    cell.dateLabel.text = [[_dateFormatter stringFromDate: [file objectForKey:@"date"]] stringByReplacingOccurrencesOfString:@"," withString:@""];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIUtils surespotSelectionBlue];
    bgColorView.layer.masksToBounds = YES;
    cell.selectedBackgroundView = bgColorView;
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[IdentityController sharedInstance] getIdentityCount] >= MAX_IDENTITIES) {
        [UIUtils showToastMessage:[NSString stringWithFormat: NSLocalizedString(@"login_max_identities_reached",nil), MAX_IDENTITIES] duration:2];
        return;
    }
    
    NSDictionary * rowData = [_documentsIdentities objectAtIndex:indexPath.row];
    NSString * name = [rowData objectForKey:@"name"];
    NSString * file = [rowData objectForKey:@"filename"];
    
    _storedPassword = [[IdentityController sharedInstance] getStoredPasswordForIdentity:name];
    _name = name;
    _file = file;
    
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"restore_identity", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
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
            [self importIdentity:_name filename:_file password:password];
        }
    }
}

-(void) importIdentity: (NSString *) name filename: (NSString *) filename password: (NSString *) password {
    BOOL imported = [[IdentityController sharedInstance] importIdentityFilename:filename username:name password:password];
    if (imported) {
        [UIUtils showToastKey:@"identity_imported_successfully" duration:2];
        
        
        //update stored password
        if (![UIUtils stringIsNilOrEmpty:_storedPassword] && ![_storedPassword isEqualToString:password]) {
            [[IdentityController sharedInstance] storePasswordForIdentity:name password:password];
        }
        
        _storedPassword = nil;
        
        //if we now only have 1 identity, go to login view controller
        if ([[[IdentityController sharedInstance] getIdentityNames] count] == 1) {
            UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
            [self.navigationController setViewControllers:@[[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"]]];
        }

    }
    else {
        [UIUtils showToastKey:@"could_not_import_identity" duration:2];
    }
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}

@end
