/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceViewController.h"
#import "NotificationHelper.h"
#import "MessagingServiceConversationViewController.h"

@interface MessagingServiceViewController ()

@end

@implementation MessagingServiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshConversationList:) name:kRefreshConversationListNotification object:nil];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshConversationListNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    MessagingServiceConversationViewController *vc = (MessagingServiceConversationViewController *)segue.destinationViewController;
    if([segue.identifier isEqualToString:@"openConversationDetails"]) {
        
        NSLog(@"%s Perform Open Conversation Screen segue", __PRETTY_FUNCTION__);
        NSLog(@"%s selected Conversation = [%@]", __PRETTY_FUNCTION__, self.selectedConversation);
        vc.selectedConversation = self.selectedConversation;
    }
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSLog(@"%s conversation count: [%lu]", __PRETTY_FUNCTION__, (unsigned long)[SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot.count);
    return [SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSArray *logItems = [SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot;
    
    CSMessagingConversation *item = logItems[indexPath.row];
    
    static NSString *tableIdentifier = @"conversation";
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tableIdentifier];
    
    if (item.isActive) {
        
        NSLog(@"%s item: [%@]", __PRETTY_FUNCTION__, item);
        
        NSString *list = @"";
        for (CSParticipant* participant in item.allParticipants) {
            
            if ([participant.address isEqualToString:[[[SDKManager getInstance] users].firstObject messagingService].selfAddress]) {
                
                continue;
            } else {
                
                NSLog(@"%s participant: [%@]", __PRETTY_FUNCTION__, participant.displayName);
                list = [list stringByAppendingString: [NSString stringWithFormat:@"%@ ", participant.displayName]];
            }
        }
        cell.textLabel.text = list;
        NSString *unreadCount = @"";
        
        if (item.unreadMessageCount > 0) {
            
            unreadCount = [NSString stringWithFormat:@"%lu unread text", (unsigned long)item.unreadMessageCount];
        }
        
        if (item.unreadAttachmentCount > 0) {
            
            unreadCount = [unreadCount stringByAppendingString:[NSString stringWithFormat:@" %lu unread media", (unsigned long)item.unreadAttachmentCount]];
        }
        cell.detailTextLabel.text = unreadCount;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"%s selected row: [%ld]", __PRETTY_FUNCTION__, (long)(indexPath.row + 1));
    self.selectedConversation = [SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot[indexPath.row];
    NSLog(@"%s conversation:[%@]", __PRETTY_FUNCTION__, self.selectedConversation);
    [self performSegueWithIdentifier:@"openConversationDetails" sender:self];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([[SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot[indexPath.row] leaveCapability].allowed) {
        
        // Return YES only if we can leave the conversation
        return YES;
    } else {
        
        return NO;
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return @"Leave";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // Leave the conversation
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[SDKManager getInstance].messagingServiceManager.conversationsWatcher.snapshot[indexPath.row] leaveWithCompletionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while leaving conversation. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
        } else {
            
            NSLog(@"%s Successfully left the conversation", __PRETTY_FUNCTION__);
        }
    }];
}

#pragma mark - NSNotifications

- (void)refreshConversationList:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.conversationList reloadData];
}

@end
