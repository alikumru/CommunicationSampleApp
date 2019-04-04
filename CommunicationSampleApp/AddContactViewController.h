/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>

@interface AddContactViewController : UIViewController <UITextFieldDelegate>

- (IBAction)saveBtn:(id)sender;
@property (nonatomic, weak) IBOutlet UITextField *firstName;
@property (nonatomic, weak) IBOutlet UITextField *lastName;
@property (nonatomic, weak) IBOutlet UITextField *workNumber;
@property (nonatomic, weak) IBOutlet UITextField *workEmail;
@end
