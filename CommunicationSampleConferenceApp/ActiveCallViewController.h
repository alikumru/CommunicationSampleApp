/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "NotificationHelper.h"
#import "SDKManager.h"
#import "MediaManager.h"

@interface ActiveCallViewController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *callDuration;
@property (nonatomic, weak) IBOutlet UILabel *callState;
@property (nonatomic, weak) IBOutlet UITextView *participantList;
@property (nonatomic, weak) IBOutlet UIButton *endCallBtn;
@property (nonatomic, weak) IBOutlet UISwitch *speakerPhoneSwitch;
@property (nonatomic, weak) IBOutlet UIView *remoteVideoView;
@property (nonatomic, weak) IBOutlet UIView *localVideoView;
@property (nonatomic, weak) IBOutlet UILabel *remoteVideoLabel;
@property (weak, nonatomic) IBOutlet UISwitch *muteSwitch;
@property (nonatomic, weak) IBOutlet UILabel *localVideoLabel;
@property (nonatomic, weak) IBOutlet UIButton *conferenceControlBtnLabel;
@property (nonatomic, weak) IBOutlet UIButton *holdCallBtn;

@property (nonatomic, weak) CSCall *currentCall;

- (IBAction)endCallBtnClicked:(id)sender;
- (IBAction)muteSwitchValueChanged:(id)sender;
- (IBAction)speakerPhoneSwitchValueChanged:(id)sender;
- (IBAction)holdCallBtnClicked:(id)sender;
@end
