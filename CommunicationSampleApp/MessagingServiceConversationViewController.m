/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceConversationViewController.h"
#import "NotificationHelper.h"
#import "MessagingServiceConversationMediaViewController.h"

@interface MessagingServiceConversationViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;
@property (nonatomic, weak) CSDataRetrievalWatcher* conversationMessageWatcher;
@property (nonatomic, weak) CSMessage* message;
@property (nonatomic) BOOL fileAttached;
@property (nonatomic, strong) NSURL *fileToBeAttached;

@end

@implementation MessagingServiceConversationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"%s selected conversation: [%@]", __PRETTY_FUNCTION__, self.selectedConversation);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshConversation:) name:kRefreshConversationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(participantTyping:) name:kParticipantTypingNotification object:nil];
    
    self.conversationMessageWatcher = [[SDKManager getInstance].messagingServiceManager messagesWatcherForConversationId:self.selectedConversation.conversationId];
    [self.conversationMessageWatcher addDelegate:[SDKManager getInstance].messagingServiceManager];
    
    self.conversationMessages.text = @"";
    
    [self refreshConversation:nil];
    
    //Hide keyboard once clicked outside of keyboard
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
    
    self.chatMessage.delegate = self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshConversationNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kParticipantTypingNotification object:nil];
    [self.view removeGestureRecognizer:self.tap];
    
    [self.conversationMessageWatcher addDelegate:nil];
    self.conversationMessageWatcher = nil;
}

- (void)dismissKeyboard {
    
    [self.chatMessage resignFirstResponder];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)refreshConversation:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSString *list = @"";
    for (CSParticipant* participant in self.selectedConversation.allParticipants) {
        
        if ([participant.address isEqualToString:[[SDKManager getInstance].users.firstObject messagingService].selfAddress]) {
            
            continue;
        }
        list = [list stringByAppendingString: [NSString stringWithFormat:@"%@ ", participant.displayName]];
    }
    [self setTitle:list];
    
    self.sendBtnLabel.enabled = self.selectedConversation.createMessageCapability.allowed;
    
    [self.selectedConversation retrieveMessagesWithWatcher:self.conversationMessageWatcher];
    
    self.conversationMessages.text = @"";
    
    for (CSMessage *msg in [self.conversationMessageWatcher.snapshot reverseObjectEnumerator]) {
        
        if (msg.fromMe) {
            
            for (CSParticipant* participant in self.selectedConversation.allParticipants) {
                
                if ([participant.address isEqualToString:[[[SDKManager getInstance] users].firstObject messagingService].selfAddress]) {
                    
                    self.conversationMessages.text = [self.conversationMessages.text stringByAppendingString: [NSString stringWithFormat:@"%@: %@\n", participant.displayName, msg.body]];
                    break;
                }
            }
        } else {
            
            self.conversationMessages.text = [self.conversationMessages.text stringByAppendingString: [NSString stringWithFormat:@"%@: %@\n", msg.fromParticipant.displayName, msg.body]];
        }
        
        if (msg.markAsReadCapability.allowed) {
            
            [msg markAsRead];
        }
    }
}

- (void)participantTyping:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    NSString* participantName = notification.object;
    if (participantName.length != 0) {
        
        self.typingParticipantName.hidden = NO;
        self.typingParticipantName.text = [NSString stringWithFormat:@"%@ is typing...", notification.object];
    } else {
        
        self.typingParticipantName.hidden = YES;
        self.typingParticipantName.text = @"";
    }
}

- (IBAction)sendBtn:(id)sender {
    
    CSMessage *msg = [self.selectedConversation createMessage];
    __block CSMessage *messageToSend = msg;
    [msg setBodyAndReportTyping:self.chatMessage.text completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Cannot create message. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Cannot create message. Error code [%ld] - %@", (long)error.code, error.localizedDescription]  TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s message created successfully", __PRETTY_FUNCTION__);
            
            if (self.fileAttached) {
                
                CSMessagingAttachment *attachment = [messageToSend createAttachment];
                
                if (attachment) {
                    
                    NSLog(@"%s Attach file to message", __PRETTY_FUNCTION__);
                    [attachment setName:[self.fileToBeAttached lastPathComponent] completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error while setting name of attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while setting name of attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                        } else {
                            
                            NSLog(@"%s Successfully set name of attachment", __PRETTY_FUNCTION__);
                        }
                    }];
                    
                    [attachment setIsThumbnail:NO completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error while setting 'IsThumbnail' attribute of attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while setting 'IsThumbnail' attribute of attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                        } else {
                            
                            NSLog(@"%s Successfully set 'IsThumbnail' attribute of attachment", __PRETTY_FUNCTION__);
                        }
                    }];
                    
                    [attachment setIsGeneratedContent:NO completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error while setting 'IsGeneratedContent' attribute of attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while setting 'IsGeneratedContent' attribute of attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                        } else {
                            
                            NSLog(@"%s Successfully set 'IsGeneratedContent' attribute of attachment", __PRETTY_FUNCTION__);
                        }
                    }];
                    
                    [attachment setLocation: [NSString stringWithFormat:@"%@", self.fileToBeAttached.path] completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error while setting location of attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while setting name of attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                        } else {
                            
                            NSLog(@"%s Successfully set location of attachment", __PRETTY_FUNCTION__);
                        }
                    }];
                    
                    [attachment setMimeType:@"*/*" completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error while setting mime type of attachment. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while setting mime type of attachment. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                        } else {
                            
                            NSLog(@"%s Successfully set mime type of attachment", __PRETTY_FUNCTION__);
                        }
                    }];
                } else {
                    
                    NSLog(@"%s Error while creating attachment", __PRETTY_FUNCTION__);
                    [NotificationHelper displayMessageToUser: @"Error while creating attachment" TAG: __PRETTY_FUNCTION__];
                }
                self.fileAttached = NO;
                self.fileToBeAttached = nil;
            } else {
                
                NSLog(@"%s no attachment with this message", __PRETTY_FUNCTION__);
            }
            
            [messageToSend sendWithCompletionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Cannot send message. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Cannot send message. Error code [%ld] - %@", (long)error.code, error.localizedDescription]  TAG: __PRETTY_FUNCTION__];
                } else {
                    
                    NSLog(@"%s message sent successfully", __PRETTY_FUNCTION__);
                    self.chatMessage.text = @"";
                }
            }];
        }
    }];
}

- (IBAction)attachMediaBtn:(id)sender {
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    
    picker.delegate = self;
    picker.allowsEditing = YES;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:picker.sourceType];
    
    [self presentViewController:picker animated:YES completion:nil];
    self.chatMessage.text = [NSString stringWithFormat:@"attachment: [%@]", [self.fileToBeAttached lastPathComponent]];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    MessagingServiceConversationMediaViewController *vc = (MessagingServiceConversationMediaViewController *)segue.destinationViewController;
    if([segue.identifier isEqualToString:@"openConversationMedia"]) {
        
        NSLog(@"%s Perform Open Conversation Media Screen segue", __PRETTY_FUNCTION__);
        NSLog(@"%s selected Conversation = [%@]", __PRETTY_FUNCTION__, self.selectedConversation);
        vc.selectedConversation = self.selectedConversation;
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    
    NSString *mediaType = [info valueForKey:UIImagePickerControllerMediaType];
    if ([mediaType isEqualToString:@"public.movie"]) {
        
        NSURL *chosenVideo = [info valueForKey:UIImagePickerControllerMediaURL];
        self.fileAttached = YES;
        self.fileToBeAttached = chosenVideo;
    } else if ([mediaType isEqualToString:@"public.image"]) {
        
        // Get the chosen image
        UIImage *chosenImage = [info valueForKey:UIImagePickerControllerOriginalImage];
        
        // Save it in documents directory for sending
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *basePathsArray = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
        NSString *downloadLocation = [basePathsArray[0] path];
        downloadLocation = [downloadLocation stringByAppendingString:@"/image.png"];
        
        NSData *imageData = UIImagePNGRepresentation(chosenImage);
        
        [imageData writeToFile:downloadLocation atomically:YES];
        
        NSLog(@"%s downloadLocation: [%@]", __PRETTY_FUNCTION__, [NSString stringWithFormat:@"%@", downloadLocation]);
        
        // Get the URL for the image to be sent
        self.fileToBeAttached = [NSURL fileURLWithPath:downloadLocation];
        self.fileAttached = YES;
    }
    NSLog(@"%s Chosen Media: path:[%@], name:[%@]", __PRETTY_FUNCTION__, self.fileToBeAttached.path, [self.fileToBeAttached lastPathComponent]);
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField{
    
    [self animateTextField:textField up:YES withOffset:textField.frame.origin.y / 2];
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    
    [self animateTextField:textField up:NO withOffset:textField.frame.origin.y / 2];
    
}
-(BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    [textField resignFirstResponder];
    return true;
}

- (void)animateTextField:(UITextField*)textField up:(BOOL)up withOffset:(CGFloat)offset
{
    const int movementDistance = -offset;
    const float movementDuration = 0.4f;
    int movement = (up ? movementDistance : -movementDistance);
    [UIView beginAnimations: @"animateTextField" context: nil];
    [UIView setAnimationBeginsFromCurrentState: YES];
    [UIView setAnimationDuration: movementDuration];
    self.view.frame = CGRectOffset(self.view.frame, 0, movement);
    [UIView commitAnimations];
}

@end
