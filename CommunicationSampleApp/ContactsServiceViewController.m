/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ContactsServiceViewController.h"
#import "ContactDetailsScreenViewController.h"
#import "ContactSearchViewController.h"
#import "SDKManager.h"
#import "NotificationHelper.h"

@interface ContactsServiceViewController ()

@end

@implementation ContactsServiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Update 'Add Contact' feature availability
    [self contactServiceStatusChanged:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactServiceStatusChanged:) name:kContactServiceAvailabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshContactList:) name:kRefreshContactListNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactListUpdated:) name:kContactListUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contactListUpdated:) name:kContactPresenceUpdatedNotification object:nil];
    
    self.contactService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        
        if (user.contactService) {
            
            self.contactService = user.contactService;
            break;
        }
    }
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContactServiceAvailabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshContactListNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContactListUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContactPresenceUpdatedNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    if([segue.identifier isEqualToString:@"showContactDetails"]) {
        
        ContactDetailsScreenViewController *vc = (ContactDetailsScreenViewController *)segue.destinationViewController;
        NSLog(@"%s Perform Contact Details Screen segue", __PRETTY_FUNCTION__);
        NSLog(@"%s selected Contact = [%@]", __PRETTY_FUNCTION__, self.selectedContact);
        vc.contact = self.selectedContact;
    } if([segue.identifier isEqualToString:@"contactSearchSegue"]) {
        
        ContactSearchViewController *vc = (ContactSearchViewController *)segue.destinationViewController;
        NSLog(@"%s Perform Contact Search Screen segue", __PRETTY_FUNCTION__);
        NSLog(@"%s Contact service = [%@]", __PRETTY_FUNCTION__, self.contactService);
        vc.contactService = self.contactService;
    }
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSLog(@"%s Number of contacts: [%lu]", __PRETTY_FUNCTION__, (unsigned long)[SDKManager getInstance].contacts.count);
    return [SDKManager getInstance].contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *tableIdentifier = @"ContactName";
    
    NSArray *contactList = [SDKManager getInstance].contacts;
    
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
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"%s selected row: [%ld]", __PRETTY_FUNCTION__, (long)(indexPath.row + 1));
    self.selectedContact = [SDKManager getInstance].contacts[indexPath.row];
    NSLog(@"%s contact:[%@]", __PRETTY_FUNCTION__, self.selectedContact);
    [self performSegueWithIdentifier:@"showContactDetails" sender:self];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Return if contact can be deleted
    return [[SDKManager getInstance].contacts[indexPath.row] deleteCapability].allowed;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Delete contact from local storage and server
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CSContactService *contactService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.contactService) {
            contactService = user.contactService;
            break;
        }
    }
    
    [contactService deleteContact:[SDKManager getInstance].contacts[indexPath.row] completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while deleting contact. Error code [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while deleting contact. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG:__PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Contact deleted successfully", __PRETTY_FUNCTION__);
            [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
        }
    }];
}

#pragma mark - NSSNotifications

- (void)contactServiceStatusChanged:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    CSContactService *contactService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.contactService) {
            contactService = user.contactService;
            break;
        }
    }
    
    self.addContactBtnLabel.enabled = contactService.addContactCapability.allowed;
}

- (void)contactListUpdated:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSLog(@"%s contactList: [%@]", __PRETTY_FUNCTION__, self.contactList);
    [self.contactList reloadData];
}

- (void)refreshContactList:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // Cancel all previously registered watcher
    if (![SDKManager getInstance].contactsRetrievalWatcher.isCancelled) {
        [[SDKManager getInstance].contactsRetrievalWatcher cancel];
    }
    CSContactService *contactService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.contactService) {
            contactService = user.contactService;
            break;
        }
    }
    
    // Retrieve contacts from all sources
    [contactService retrieveContactsForSource:CSContactSourceTypeAll watcher:[SDKManager getInstance].contactsRetrievalWatcher];
}

@end
