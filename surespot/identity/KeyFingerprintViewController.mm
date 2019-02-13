//
//  KeyFingerprintViewController.m
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 surespot. All rights reserved.
//

#import "KeyFingerprintViewController.h"
#import "SurespotIdentity.h"
#import "IdentityController.h"
#import "IdentityKeys.h"
#import "EncryptionController.h"
#import "CredentialCachingController.h"
#import "DDLog.h"
#import "GetPublicKeysOperation.h"
#import "KeyFingerprintCell.h"
#import "KeyFingerprint.h"
#import "KeyFingerprintCollectionCell.h"
#import "KeyFingerprintLoadingCell.h"
#import "NetworkController.h"
#import "UIUtils.h"
#import "UsernameAliasMap.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface KeyFingerprintViewController()
@property (strong, nonatomic) UsernameAliasMap * username;
@property (strong, nonatomic) NSMutableDictionary * myFingerprints;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableDictionary * theirFingerprints;
@property (strong, nonatomic) NSOperationQueue * queue;
@property (assign, nonatomic) BOOL meFirst;
@property (assign, nonatomic) NSInteger theirLatestVersion;
@property (nonatomic, strong) dispatch_queue_t dateFormatQueue;
@property (nonatomic, strong) NSDateFormatter * dateFormatter;
@end

@implementation KeyFingerprintViewController

-(id) initWithNibName:(NSString *)nibNameOrNil username: (UsernameAliasMap *) username {
    self = [super initWithNibName:nibNameOrNil bundle:nil];
    if (self) {
        _username = username;
        _queue = [NSOperationQueue new];
        _theirLatestVersion = 1;
        _dateFormatQueue = dispatch_queue_create("date format queue fp", NULL);
        _dateFormatter = [[NSDateFormatter alloc]init];
        [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
        [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
        
        
        
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"public_key_fingerprints", nil);
    
    [_tableView registerNib:[UINib nibWithNibName:@"KeyFingerprintCell" bundle:nil] forCellReuseIdentifier:@"KeyFingerprintCell"];
    [_tableView registerNib:[UINib nibWithNibName:@"KeyFingerprintLoadingView" bundle:nil] forCellReuseIdentifier:@"KeyFingerprintLoadingCell"];
    
    _tableView.rowHeight = 110;
    
    
    //generate fingerprints
    SurespotIdentity * identity = [[CredentialCachingController sharedInstance] getLoggedInIdentity];
    
    //sort by name
    
    _meFirst = [[_username username] compare:identity.username options:NSCaseInsensitiveSearch] > 0 ? YES : NO;
    
    
    //todo handle no identity
    
    _myFingerprints = [NSMutableDictionary new];
    
    //make sure all the keys are in memory
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [identity recreateMissingKeys];
        
        for (IdentityKeys *keys in [identity.keyPairs allValues]) {
            NSString * version = keys.version;
            NSData * dhData = [EncryptionController encodeDHPublicKeyData:keys.dhPubKey];
            NSData * dsaData = [EncryptionController encodeDSAPublicKeyData:keys.dsaPubKey];
            
            NSMutableDictionary * dict = [NSMutableDictionary new];
            [dict setObject: version forKey:@"version"];
            NSString * md5dh = [EncryptionController md5:dhData];
            [dict setObject:[[KeyFingerprint alloc] initWithFingerprintData:md5dh forTitle:@"DH"] forKey:@"dh"];
            
            NSString * md5dsa = [EncryptionController md5:dsaData];
            [dict setObject:[[KeyFingerprint alloc] initWithFingerprintData:md5dsa forTitle:@"DSA"] forKey:@"dsa"];
            
            //reverse order
            [_myFingerprints setObject:dict forKey:[@([identity.latestVersion integerValue]-[version integerValue]) stringValue]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableView reloadData];
            
        });
        
    });
    
    _theirFingerprints = [NSMutableDictionary new];
    [self addAllPublicKeysForUsername:[_username username] toDictionary:_theirFingerprints];
    
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return _meFirst ? [[[[CredentialCachingController sharedInstance] getLoggedInIdentity] latestVersion] integerValue] : [self theirCount];
            break;
        case 1:
            return _meFirst ? [self theirCount] :  [[[[CredentialCachingController sharedInstance] getLoggedInIdentity] latestVersion] integerValue];
            break;
        default:
            return 0;
    }
}

- (NSInteger) theirCount {
    return ( _theirFingerprints.count < _theirLatestVersion ? _theirLatestVersion :_theirFingerprints.count);
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    BOOL useMyData = (_meFirst && indexPath.section == 0) || (!_meFirst && indexPath.section == 1);
    NSDictionary * cellData = useMyData ?[ _myFingerprints objectForKey:[@(indexPath.row) stringValue] ] : [ _theirFingerprints objectForKey:[@(indexPath.row) stringValue] ];
    
    if (cellData) {
        KeyFingerprintCell *cell = [_tableView dequeueReusableCellWithIdentifier:@"KeyFingerprintCell"];
        BOOL hideTime = (_meFirst && indexPath.section == 0) || (!_meFirst && indexPath.section == 1);
        cell.timeLabel.hidden = hideTime;
        cell.timeValue.hidden = hideTime;
        
        if (!hideTime) {
            cell.timeLabel.text = NSLocalizedString(@"received", nil);
            cell.timeValue.text = [cellData objectForKey:@"lastVerified"];
        }
        
        cell.versionLabel.text = NSLocalizedString(@"version", nil);
        cell.versionValue.text = [cellData objectForKey:@"version"];
        
        [[cell.dhView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        UICollectionViewFlowLayout * fl =[UICollectionViewFlowLayout new];
        [fl setMinimumLineSpacing:0];
        [fl setMinimumInteritemSpacing:0];
        [fl setItemSize:CGSizeMake(20, 18)];
        UICollectionView * collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, 160, 140) collectionViewLayout:fl];
        [collectionView setBackgroundColor:[UIColor whiteColor]];
        [collectionView setOpaque:YES];
        collectionView.dataSource = [cellData objectForKey:@"dh"];
        [collectionView registerClass:[KeyFingerprintCollectionCell class] forCellWithReuseIdentifier:@"KeyFingerprintCollectionCell"];
        //
        [cell.dhView addSubview:collectionView];
        
        fl =[UICollectionViewFlowLayout new];
        [fl setMinimumLineSpacing:0];
        [fl setMinimumInteritemSpacing:0];
        [fl setItemSize:CGSizeMake(20, 18)];
        
        
        [[cell.dsaView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0,0, 160, 140) collectionViewLayout:fl];
        [collectionView setBackgroundColor:[UIColor whiteColor]];
        [collectionView setOpaque:YES];
        collectionView.dataSource = [cellData objectForKey:@"dsa"];
        [collectionView registerClass:[KeyFingerprintCollectionCell class] forCellWithReuseIdentifier:@"KeyFingerprintCollectionCell"];
        [cell.dsaView addSubview:collectionView];
        
        [cell setOpaque:YES];
        [cell setUserInteractionEnabled:NO];
        return cell;
    }
    else {
        KeyFingerprintLoadingCell * cell = [_tableView dequeueReusableCellWithIdentifier:@"KeyFingerprintLoadingCell"];
        cell.keyFingerprintLoadingLabel.text= NSLocalizedString(@"loading", nil);
        return cell;
    }
    
}


-(void) addAllPublicKeysForUsername: (NSString *) username toDictionary: (NSMutableDictionary *) dictionary {
    [[NetworkController sharedInstance] getKeyVersionForUsername:username
                                                    successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                        NSString * latestVersion = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                                        if ([latestVersion length] > 0) {
                                                            _theirLatestVersion = [latestVersion integerValue];
                                                            [_tableView reloadData];
                                                            
                                                            for (int ver=_theirLatestVersion;ver>0;ver--) {
                                                                NSString * version = [@(ver) stringValue];
                                                                
                                                                //get public keys out of dictionary
                                                                NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", username, version];
                                                                PublicKeys * publicKeys = [[[CredentialCachingController sharedInstance] publicKeysDict] objectForKey:publicKeysKey];
                                                                
                                                                if (!publicKeys) {
                                                                    DDLogVerbose(@"public keys not cached for %@", publicKeysKey );
                                                                    
                                                                    //get the public keys we need
                                                                    GetPublicKeysOperation * pkOp = [[GetPublicKeysOperation alloc] initWithUsername:username version:version completionCallback:
                                                                                                     ^(PublicKeys * keys) {
                                                                                                         if (keys) {
                                                                                                             //reverse the order
                                                                                                             [dictionary setObject:[self createDictionaryForPublicKeys:keys] forKey:[@(_theirLatestVersion-ver) stringValue]];
                                                                                                             dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                 [_tableView reloadData];
                                                                                                             });
                                                                                                         }
                                                                                                         else {
                                                                                                             //failed to get keys
                                                                                                             DDLogVerbose(@"could not get public key for %@", publicKeysKey );
                                                                                                             
                                                                                                         }
                                                                                                         
                                                                                                         
                                                                                                     }];
                                                                    
                                                                    [_queue addOperation:pkOp];
                                                                    
                                                                    
                                                                }
                                                                else {
                                                                    [dictionary setObject:[self createDictionaryForPublicKeys:publicKeys] forKey:[@(_theirLatestVersion-ver) stringValue]];
                                                                    [_tableView reloadData];
                                                                }
                                                            }
                                                        }
                                                        
                                                    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                        [UIUtils showToastKey:@"could_not_load_public_keys"];
                                                    }
     ];
}

-(NSDictionary *) createDictionaryForPublicKeys: (PublicKeys *) keys {
    
    
    NSData * dhData = [EncryptionController encodeDHPublicKeyData: keys.dhPubKey];
    NSData * dsaData = [EncryptionController encodeDSAPublicKeyData:keys.dsaPubKey];
    
    NSMutableDictionary * dict = [NSMutableDictionary new];
    [dict setObject: keys.version forKey:@"version"];
    
    NSString * md5dh = [EncryptionController md5:dhData];
    [dict setObject:[[KeyFingerprint alloc] initWithFingerprintData:md5dh forTitle:@"DH"] forKey:@"dh"];
    
    NSString * md5dsa = [EncryptionController md5:dsaData];
    [dict setObject:[[KeyFingerprint alloc] initWithFingerprintData:md5dsa forTitle:@"DSA"] forKey:@"dsa"];
    
    if (keys.lastModified) {
        [dict setObject:[[self stringFromDate: keys.lastModified] stringByReplacingOccurrencesOfString:@"," withString:@""] forKey:@"lastVerified"];
    }
    return dict;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    BOOL useMyData = (_meFirst && section == 0) || (!_meFirst && section == 1);
    return useMyData ?
        [[IdentityController sharedInstance] getLoggedInUser] :
        [UIUtils buildAliasStringForUsername:[_username username] alias:[_username alias]];
}


- (NSString *)stringFromDate:(NSDate *)date
{
    __block NSString *string = nil;
    dispatch_sync(_dateFormatQueue, ^{
        string = [[_dateFormatter stringFromDate:date ] stringByReplacingOccurrencesOfString:@"," withString:@""];
    });
    return string;
}


@end
