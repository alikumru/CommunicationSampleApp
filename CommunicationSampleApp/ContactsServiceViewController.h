/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface ContactsServiceViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UIBarButtonItem *addContactBtnLabel;
@property (nonatomic, weak) IBOutlet UITableView *contactList;

@property (nonatomic, weak)CSContact *selectedContact;
@property (nonatomic, weak) CSContactService *contactService;

@end
