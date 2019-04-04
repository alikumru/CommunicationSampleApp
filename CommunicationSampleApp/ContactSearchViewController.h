/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface ContactSearchViewController : UIViewController

@property (nonatomic, weak) IBOutlet UITextField *searchQuery;
@property (nonatomic, weak) IBOutlet UITableView *contactSearchResults;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *progressIndicator;
@property (nonatomic, weak) IBOutlet UILabel *searchStatusLabel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *searchBtnLabel;

- (IBAction)searchBtn:(id)sender;

@property (nonatomic, weak) CSContactService *contactService;

@end
