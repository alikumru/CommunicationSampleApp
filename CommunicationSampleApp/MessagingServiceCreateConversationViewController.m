/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceCreateConversationViewController.h"
#import "MessagingServiceConversationViewController.h"
#import "SDKManager.h"
#import "NotificationHelper.h"

@interface MessagingServiceCreateConversationViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation MessagingServiceCreateConversationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openConversation:) name:kOpenConversationNotification object:nil];
    
    self.createConversationLabel.enabled = [[SDKManager getInstance].users.firstObject messagingService].createConversationCapability.allowed;
    
    //Hide keyboard once clicked outside of keyboard
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kOpenConversationNotification object:nil];
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    
    [self.contactName resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)createConversationBtn:(id)sender {
    
    CSMessagingConversation *conversation = [[[[SDKManager getInstance] users].firstObject messagingService] createConversation];
    NSLog(@"%s createdConversation: [%@]", __PRETTY_FUNCTION__, conversation);
    
    CSMessagingConversation *msg = conversation;
    [conversation addParticipantAddresses:[NSArray arrayWithObject:self.contactName.text] completionHandler:^(NSArray *participants, NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while creating conversation. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully created conversation", __PRETTY_FUNCTION__);
            [msg startWithCompletionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Error while starting conversation. Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                } else {
                    
                    NSLog(@"%s Successfully started conversation", __PRETTY_FUNCTION__);
                    self.createdConversation = msg;
                    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationListNotification object:nil];
                    [[NSNotificationCenter defaultCenter] postNotificationName:kOpenConversationNotification object:nil];
                }
            }];
        }
    }];
}

- (void)openConversation:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    UIStoryboard *mainStoryBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MessagingServiceConversationViewController *vc = (MessagingServiceConversationViewController *)[mainStoryBoard instantiateViewControllerWithIdentifier:@"ConversationDetailsScreen"];
    vc.selectedConversation = self.createdConversation;
    [self.navigationController pushViewController: vc animated:YES];
}

@end
