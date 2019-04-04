/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface MessagingServiceConversationViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UITextFieldDelegate>

@property (nonatomic, weak) CSMessagingConversation *selectedConversation;

@property (nonatomic, weak) IBOutlet UILabel *typingParticipantName;
@property (nonatomic, weak) IBOutlet UITextView *conversationMessages;
@property (nonatomic, weak) IBOutlet UIButton *sendBtnLabel;
@property (nonatomic, weak) IBOutlet UITextField *chatMessage;

- (IBAction)sendBtn:(id)sender;
- (IBAction)attachMediaBtn:(id)sender;

@end
