/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ContactSearchViewController.h"
#import "NotificationHelper.h"

@interface ContactSearchViewController ()<CSDataRetrievalWatcherDelegate, CSContactDelegate>

@property (nonatomic) CSDataRetrievalWatcher *contactsSearchWatcher;
@property (nonatomic) NSMutableArray *searchResults;
@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation ContactSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSearchResults:) name:kSearchResultUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSearchResults:) name:kSearchedContactPresenceUpdatedNotification object:nil];
    
    NSLog(@"%s received CSContactService: %@", __PRETTY_FUNCTION__, self.contactService);
    
    // Do not allow search if we dont get CSContactService
    if (self.contactService == nil) {
        
        self.searchQuery.enabled = NO;
        self.searchBtnLabel.enabled = NO;
    }
    
    //Hide keyboard once clicked outside of keyboard
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSearchResultUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSearchedContactPresenceUpdatedNotification object:nil];
    [self.view removeGestureRecognizer:self.tap];
    
    // Stop presence subscription for the contacts in search results
    [self clearPresenceSubscription];
    
    if (self.contactsSearchWatcher) {
        
        // Cancel any previously started search requests
        NSLog(@"%s Cancel any previously started search requests", __PRETTY_FUNCTION__);
        [self.contactsSearchWatcher cancel];
    }
    
    [self.contactsSearchWatcher addDelegate:nil];
    self.contactsSearchWatcher = nil;
    
    // Start presence subscription for the contacts in user's contact list
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
}

- (void)dismissKeyboard {
    
    [self.searchQuery resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)reloadSearchResults:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.contactSearchResults reloadData];
}

- (IBAction)searchBtn:(id)sender {
    
    self.progressIndicator.hidden = NO;
    [self.progressIndicator startAnimating];
    self.searchStatusLabel.hidden = NO;
    
    [self clearPresenceSubscription];
    
    if (self.contactsSearchWatcher) {
        
        // Cancel any previously started search requests
        NSLog(@"%s Cancel any previously started search requests", __PRETTY_FUNCTION__);
        [self.contactsSearchWatcher cancel];
    }
    
    self.contactsSearchWatcher = [[CSDataRetrievalWatcher alloc] init];
    [self.contactsSearchWatcher addDelegate:self];
    
    if (self.contactService.networkSearchContactCapability.allowed) {
        
        NSLog(@"%s Network search allowed", __PRETTY_FUNCTION__);
        [self.contactService searchContactsWithSearchString:self.searchQuery.text searchScope:CSContactSearchScopeAll searchLocation:CSContactSearchAll maxNumberOfResults:100 maxChunkSize:50 watcher:self.contactsSearchWatcher];
    } else {
        
        NSLog(@"%s network search denied", __PRETTY_FUNCTION__);
        [self.contactService searchContactsWithSearchString:self.searchQuery.text searchScope:CSContactSearchScopeAll searchLocation:CSContactSearchLocalCache maxNumberOfResults:100 maxChunkSize:50 watcher:self.contactsSearchWatcher];
    }
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSDataRetrievalWatcherDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didUpdateProgress:(BOOL)determinate retrievedCount:(NSUInteger)retrievedCount totalCount:(NSUInteger)totalCount {
    
    NSLog(@"%s retrieved count: [%lu], total count: [%lu]", __PRETTY_FUNCTION__, (unsigned long)retrievedCount, (unsigned long)totalCount);
}

- (void)dataRetrievalWatcherDidComplete:(CSDataRetrievalWatcher *)dataRetrievalWatcher {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.searchResults removeAllObjects];
    NSArray *contactsSnapshot = dataRetrievalWatcher.snapshot;
    self.searchResults = [[NSMutableArray alloc]initWithArray:contactsSnapshot];
    for (CSContact *contact in self.searchResults) {
        
        contact.delegate = self;
        
        // Start watching presence of Enterprise contacts
        if ([contact hasContactSourceType:CSContactSourceTypeEnterprise]) {
            
            [contact startPresenceWithAccessControlBehavior:CSAccessControlBehaviorNone completionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                } else {
                    
                    NSLog(@"%s presence subscription successful for search contact: [%@]", __PRETTY_FUNCTION__, contact);
                }
            }];
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kSearchResultUpdatedNotification object:nil];
    self.progressIndicator.hidden = YES;
    [self.progressIndicator stopAnimating];
    self.searchStatusLabel.hidden = YES;
}

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didFailWithError:(NSError *)error {
    
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
    self.progressIndicator.hidden = YES;
    [self.progressIndicator stopAnimating];
    self.searchStatusLabel.hidden = YES;
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
}

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didContentsChange:(CSDataCollectionChangeType)changeType changedItems:(NSArray *)changedItems {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    switch(changeType) {
        case CSDataCollectionChangeTypeAdded:
            
            NSLog(@"%s %lu Contact added", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                [self.searchResults addObject:contact];
            }
            break;
            
        case CSDataCollectionChangeTypeUpdated:
            NSLog(@"%s %lu contact updated.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            break;
            
        case CSDataCollectionChangeTypeDeleted:
            NSLog(@"%s %lu Contact deleted", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                [self.searchResults removeObject:contact];
            }
            break;
            
        case CSDataCollectionChangeTypeCleared:
            NSLog(@"%s %lu Contact cleared", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                [self.searchResults removeObject:contact];
            }
            break;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kSearchResultUpdatedNotification object:nil];
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSContactDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)contactUpdated:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contactDidStartPresence:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contactDidStopPresence:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contact:(CSContact *)contact didUpdatePresence:(CSPresence *)presence {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kSearchedContactPresenceUpdatedNotification object:contact];
}

////////////////////////////////////////////////

- (void)clearPresenceSubscription {
    
    for (CSContact *contact in self.searchResults) {
        
        contact.delegate = nil;
        if (contact.isBuddy) {
            
            [contact stopPresenceWithCompletionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Error while stop tracking Presence for contact [%@]", __PRETTY_FUNCTION__, contact);
                } else {
                    
                    NSLog(@"%s Successfully stopped tracking Presence for contact [%@]", __PRETTY_FUNCTION__, contact);
                }
            }];
        }
    }
}

/////////////////////////////////////////////////

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSLog(@"%s Number of search results: [%lu]", __PRETTY_FUNCTION__, (unsigned long)self.searchResults.count);
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *tableIdentifier = @"ContactName";
    
    NSArray *contactList = [[NSArray alloc] initWithArray:self.searchResults];
    
    CSContact *contact = contactList[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableIdentifier];
    }
    
    UIImage * statusImage;
    
    switch(contact.presence.overallState) {
            
        case CSPresenceStateAvailable:
            statusImage = [UIImage imageNamed:@"available.png"];
            break;
        case CSPresenceStateAway:
            statusImage = [UIImage imageNamed:@"away.png"];
            break;
        case CSPresenceStateBusy:
            statusImage = [UIImage imageNamed:@"busy.png"];
            break;
        case CSPresenceStateDoNotDisturb:
            statusImage = [UIImage imageNamed:@"dnd.png"];
            break;
        case CSPresenceStateOffline:
            statusImage = [UIImage imageNamed:@"offline.png"];
            break;
        case CSPresenceStateOnACall:
            statusImage = [UIImage imageNamed:@"onacall.png"];
            break;
        case CSPresenceStateOutOfOffice:
            statusImage = [UIImage imageNamed:@"outofoffice.png"];
            break;
        case CSPresenceStateUnknown:
            statusImage = [UIImage imageNamed:@"unavailable.png"];
            break;
        case CSPresenceStateUnspecified:
        default:
            statusImage = [UIImage imageNamed:@"default.png"];
            break;
    }
    cell.imageView.image = statusImage;
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@", contact];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"%s selected row: [%ld]", __PRETTY_FUNCTION__, (long)(indexPath.row + 1));
}

@end
