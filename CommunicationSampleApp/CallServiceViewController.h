/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import <AvayaClientServices/AvayaClientServices.h>

@interface CallServiceViewController : UIViewController
@property (nonatomic, weak) IBOutlet UITextField *numberToCall;
@property (nonatomic, weak) IBOutlet UIButton *makeAudioCallLabel;
@property (nonatomic, weak) IBOutlet UIButton *makeVideoCallLabel;
@property (nonatomic, weak) IBOutlet UISwitch *sendAllCallsSwitch;

@property (nonatomic, weak) CSCallService *callService;
@property (nonatomic, weak) CSCallFeatureService *callFeatureService;

- (IBAction)sendAllCallsBtn:(id)sender;

@end
