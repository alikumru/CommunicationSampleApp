/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface ContactDetailsScreenViewController : UIViewController

@property (nonatomic, weak) CSContact *contact;

- (IBAction)editBtn:(id)sender;

@property (nonatomic, weak) IBOutlet UIBarButtonItem *editBtnLabel;
@property (nonatomic, weak) IBOutlet UITextField *firstName;
@property (nonatomic, weak) IBOutlet UITextField *lastName;
@property (nonatomic, weak) IBOutlet UITextField *workNumber;
@property (nonatomic, weak) IBOutlet UITextField *workEmail;

@end
