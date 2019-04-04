/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceConversationMediaViewController.h"
#import "NotificationHelper.h"

@interface MessagingServiceConversationMediaViewController ()

@property (nonatomic, weak) CSMessagingAttachment *selectedAttachment;
@property (nonatomic, weak) CSDataRetrievalWatcher* conversationMessageWatcher;

@end

@implementation MessagingServiceConversationMediaViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"%s selected conversation: [%@]", __PRETTY_FUNCTION__, self.selectedConversation);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(attachmentReceived:) name:kAttachmentReceivedNotification object:nil];
    
    self.conversationMessageWatcher = [[SDKManager getInstance].messagingServiceManager messagesWatcherForConversationId:self.selectedConversation.conversationId];
    [self.conversationMessageWatcher addDelegate:[SDKManager getInstance].messagingServiceManager];
    
    [self.selectedConversation retrieveMessagesWithWatcher:self.conversationMessageWatcher];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kAttachmentReceivedNotification object:nil];
    [self.conversationMessageWatcher addDelegate:nil];
    self.conversationMessageWatcher = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    NSLog(@"%s Number of attachments in conversation: %lu", __PRETTY_FUNCTION__, (unsigned long)self.selectedConversation.attachmentCount);
    return self.selectedConversation.attachmentCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSMutableArray *mediaItems = [[NSMutableArray alloc] init];
    
    for (CSMessage *msg in self.conversationMessageWatcher.snapshot) {
        
        for (CSMessagingAttachment *attachment in msg.attachments) {
            
            if (attachment.isThumbnail) {
                
                continue;
            } else {
                
                NSLog(@"%s attachmentName: [%@]", __PRETTY_FUNCTION__, attachment.name);
                [mediaItems addObject:attachment];
            }
        }
    }
    
    CSMessagingAttachment *item = mediaItems[indexPath.row];
    
    static NSString *tableIdentifier = @"attachmentName";
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tableIdentifier];
    
    cell.textLabel.text = item.name;
    
    NSString *status = @"";
    
    switch (item.status) {
        case CSMessagingAttachmentStatusDraft:
            status = @"Draft";
            break;
        case CSMessagingAttachmentStatusOpened:
            status = @"Opened";
            break;
        case CSMessagingAttachmentStatusSending:
            status = @"Sending";
            break;
        case CSMessagingAttachmentStatusDraftError:
            status = @"DraftError";
            break;
        case CSMessagingAttachmentStatusDownloading:
            status = @"Downloading";
            break;
        case CSMessagingAttachmentStatusReadyToOpen:
            status = @"ReadyToOpen";
            break;
        case CSMessagingAttachmentStatusReadyToDownload:
            status = @"ReadyToDownload";
            break;
        case CSMessagingAttachmentStatusDraftRemoving:
            status = @"DraftRemoving";
            break;
        default:
            break;
    }
    
    cell.detailTextLabel.text = status;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSLog(@"%s selected row: [%ld]", __PRETTY_FUNCTION__, (long)(indexPath.row + 1));
    NSMutableArray *mediaItems = [[NSMutableArray alloc] init];
    
    for (CSMessage *msg in self.conversationMessageWatcher.snapshot) {
        
        for (CSMessagingAttachment *attachment in msg.attachments) {
            
            if (attachment.isThumbnail) {
                
                continue;
            } else {
                
                [mediaItems addObject:attachment];
            }
        }
    }
    self.selectedAttachment = mediaItems[indexPath.row];
    NSLog(@"%s selected attachment: [%@]", __PRETTY_FUNCTION__, self.selectedAttachment.name);
    [self.selectedAttachment setDelegate:[SDKManager getInstance].messagingServiceManager];
    
    if (self.selectedAttachment.downloadCapability.allowed) {
        
        //Set up alert window
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Download File" message:nil preferredStyle:UIAlertControllerStyleAlert];
        
        //Define action for items in Alert
        UIAlertAction *yesAction = [UIAlertAction
                                    actionWithTitle:@"Yes"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
                                        
                                        [self downloadMedia];
                                    }];
        
        UIAlertAction *noAction = [UIAlertAction
                                   actionWithTitle:@"No"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                                       
                                       [self dismissViewControllerAnimated:YES completion:nil];
                                   }];
        
        //Add action buttons on alert window
        [alert addAction:noAction];
        [alert addAction:yesAction];
        
        //Display alert window
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        
        NSLog(@"%s No download capability for this attachment", __PRETTY_FUNCTION__);
    }
}

#pragma mark - NSNotifications

- (void)attachmentReceived:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.attachmentList reloadData];
}

#pragma mark - Media handling

- (void)downloadMedia {
    
    NSLog(@"%s Download the attachment", __PRETTY_FUNCTION__);
    
    // Save the received files in Documents directory of the Application
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *basePathsArray = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    
    NSString *downloadLocation = [basePathsArray[0] path];
    
    NSLog(@"%s downloadLocation: [%@]", __PRETTY_FUNCTION__, [NSString stringWithFormat:@"%@/%@", downloadLocation, self.selectedAttachment.name]);
    
    [self.selectedAttachment download:[NSString stringWithFormat:@"%@/%@", downloadLocation, self.selectedAttachment.name] completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while downloading attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while downloading attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully downloaded attachment", __PRETTY_FUNCTION__);
            [NotificationHelper displayMessageToUser:@"Successfully saved the file" TAG: __PRETTY_FUNCTION__];
            
            // Once the file is downloaded in Documents directory of Application, developer can move the file as per requirement.
            // e.g.: Move images and videos to Photo Library
        }
    }];
}

@end
