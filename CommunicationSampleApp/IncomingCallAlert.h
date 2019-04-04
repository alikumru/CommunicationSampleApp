/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/
#import <UIKit/UIKit.h>
#import <AvayaClientServices/AvayaClientServices.h>

@interface IncomingCallAlert : UIViewController

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIAlertController *incomingCallAlert;
@property (nonatomic, strong) UIAlertAction* acceptCall;
@property (nonatomic, strong) UIAlertAction* ignoreCall;

@property (nonatomic, weak) CSCall *incomingCall;

- (void)showIncomingCallAlert:(NSNotification *)notification;
- (void)didReceiveMissedCall:(NSNotification *)notification;

@end
