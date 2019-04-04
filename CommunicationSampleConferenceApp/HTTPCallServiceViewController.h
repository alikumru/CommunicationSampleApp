/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import <AvayaClientServices/AvayaClientServices.h>

@interface HTTPCallServiceViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, weak) IBOutlet UITextField *conferenceURLTextField;
@property (nonatomic, weak) IBOutlet UIButton *makeAudioCallLabel;
@property (nonatomic, weak) IBOutlet UIButton *makeVideoCallLabel;
@property (nonatomic, weak) IBOutlet UILabel *messageLabel;
@property (weak, nonatomic) IBOutlet UISwitch *guestLoginSwitch;
@property (weak, nonatomic) IBOutlet UILabel *displayNameLabel;
@property (weak, nonatomic) IBOutlet UITextField *displayNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *conferenceUsernameLabel;
@property (weak, nonatomic) IBOutlet UITextField *conferenceUsernameTextField;
@property (weak, nonatomic) IBOutlet UILabel *conferencePasswordLabel;
@property (weak, nonatomic) IBOutlet UITextField *conferencePasswordTextField;

@property (nonatomic, weak) CSCallService *callService;
@property (nonatomic, weak) CSUnifiedPortalService *unifiedPortalService;


@end
