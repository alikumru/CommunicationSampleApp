/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface MessagingServiceCreateConversationViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIButton *createConversationLabel;
@property (nonatomic, weak) IBOutlet UITextField *contactName;

@property (nonatomic, weak) CSMessagingConversation *createdConversation;

- (IBAction)createConversationBtn:(id)sender;

@end
