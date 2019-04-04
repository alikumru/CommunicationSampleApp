/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>

@interface MessagingServiceSettingsViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITextField *messagingServerAddress;
@property (nonatomic, weak) IBOutlet UITextField *messagingPort;
@property (nonatomic, weak) IBOutlet UIButton *messagingPollingInterval;
@property (nonatomic, weak) IBOutlet UITextField *messagingUsername;
@property (nonatomic, weak) IBOutlet UITextField *messagingPassword;
@property (nonatomic, weak) IBOutlet UILabel *messagingLoginStatusLabel;
@property (nonatomic, weak) IBOutlet UIButton *messagingPollingIntervalLabel;
@property (nonatomic, weak) IBOutlet UISwitch *messagingConnectionType;

- (IBAction)doneBtn:(id)sender;
- (IBAction)messagingPollingIntervalBtn:(id)sender;
- (IBAction)messagingConnectionTypeBtn:(id)sender;

@end
