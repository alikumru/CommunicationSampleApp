/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface MessagingServiceViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *conversationList;
@property (nonatomic, weak) IBOutlet UIButton *createChatLabel;

@property (nonatomic, weak) CSMessagingConversation *selectedConversation;

@end
