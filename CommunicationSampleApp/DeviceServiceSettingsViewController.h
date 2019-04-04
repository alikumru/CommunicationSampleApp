/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>

@interface DeviceServiceSettingsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITextField *acsServerAddress;
@property (nonatomic, weak) IBOutlet UITextField *acsPort;
@property (nonatomic, weak) IBOutlet UISwitch *acsConnectionType;
@property (nonatomic, weak) IBOutlet UITextField *acsUsername;
@property (nonatomic, weak) IBOutlet UITextField *acsPassword;
@property (nonatomic, weak) IBOutlet UILabel *acsLoginStatusLabel;

- (IBAction)acsConnectionTypeBtn:(id)sender;
- (IBAction)doneBtn:(id)sender;


@end
