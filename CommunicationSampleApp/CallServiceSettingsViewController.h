/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>

@interface CallServiceSettingsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITextField *sipProxyAddress;
@property (nonatomic, weak) IBOutlet UITextField *sipProxyPort;
@property (nonatomic, weak) IBOutlet UITextField *sipDomain;
@property (nonatomic, weak) IBOutlet UITextField *sipUsername;
@property (nonatomic, weak) IBOutlet UITextField *sipPassword;
@property (nonatomic, weak) IBOutlet UILabel *sipLoginStatus;
@property (nonatomic, weak) IBOutlet UISwitch *tlsSwitch;
@property (nonatomic, assign) UITextField *activeField;
@property (nonatomic, weak) IBOutlet UISwitch *callKitSwitch;

- (IBAction)doneBtn:(id)sender;
- (IBAction)tlsBtn:(id)sender;

@end
