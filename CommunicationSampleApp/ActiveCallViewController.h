/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "NotificationHelper.h"
#import "SDKManager.h"
#import "MediaManager.h"
#import "ContentSharingViewController.h"

@interface ActiveCallViewController : UIViewController

@property (nonatomic, weak) IBOutlet UILabel *callDuration;
@property (nonatomic, weak) IBOutlet UILabel *callState;
@property (nonatomic, weak) IBOutlet UITextField *dtmf;
@property (nonatomic, weak) IBOutlet UITextView *participantList;
@property (nonatomic, weak) IBOutlet UIButton *endCallBtn;
@property (nonatomic, weak) IBOutlet UISwitch *speakerPhoneBtn;
@property (nonatomic, weak) IBOutlet UIView *remoteVideoView;
@property (nonatomic, weak) IBOutlet UIView *localVideoView;
@property (nonatomic, weak) IBOutlet UILabel *remoteVideoLabel;
@property (weak, nonatomic) IBOutlet UISwitch *muteBtn;
@property (nonatomic, weak) IBOutlet UILabel *localVideoLabel;
@property (nonatomic, weak) IBOutlet UIButton *conferenceControlBtnLabel;
@property (nonatomic, weak) IBOutlet UIButton *collaborationBtnLabel;
@property (nonatomic, weak) IBOutlet UIButton *holdCallBtn;

@property (nonatomic, weak) CSCall *currentCall;

- (IBAction)endCallBtn:(id)sender;
- (IBAction)muteCallBtn:(id)sender;
- (IBAction)speakerPhoneBtn:(id)sender;
- (IBAction)collaborationBtn:(id)sender;
- (IBAction)holdCallBtn:(id)sender;
@end
