/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"

@interface ConferenceControlViewController : UIViewController

@property (nonatomic, weak) IBOutlet UISwitch *lockMeetingBtnLabel;
@property (nonatomic, weak) IBOutlet UIButton *muteAllBtnLabel;
@property (nonatomic, weak) IBOutlet UIButton *unMuteAllBtnLabel;

- (IBAction)lockMeetingBtn:(id)sender;
- (IBAction)muteAllBtn:(id)sender;
- (IBAction)unMuteAllBtn:(id)sender;

@property (nonatomic, weak) CSConference *conferenceCall;

@end
