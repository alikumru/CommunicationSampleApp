/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import <AvayaClientServices/AvayaClientServices.h>
#import "SDKManager.h"
#import "ActiveCallViewController.h"
#import "IncomingCallAlert.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic) UIWindow *window;
@property (nonatomic) IncomingCallAlert *incomingCallAlert;

@end

