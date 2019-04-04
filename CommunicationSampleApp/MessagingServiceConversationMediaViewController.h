/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface MessagingServiceConversationMediaViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak) CSMessagingConversation *selectedConversation;
@property (nonatomic, weak) IBOutlet UITableView *attachmentList;

@end
