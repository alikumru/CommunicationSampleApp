/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "IncomingCallAlert.h"
#import "ActiveCallViewController.h"
#import "SDKManager.h"
#import "AppDelegate.h"

@implementation IncomingCallAlert

- (void)showIncomingCallAlert:(NSNotification *)notification {
    
    NSLog(@"%s Received Incoming call notification", __PRETTY_FUNCTION__);
    
    [self setIncomingCallDetails];
    
    //Setup calling party party name and number for display
    //on incoming call alert window
    NSMutableString *displayMsg = [[NSMutableString alloc] initWithFormat:@"%@\n%@", self.incomingCall.remoteDisplayName, self.incomingCall.remoteNumber];
    
    
    AppDelegate *delegate = (AppDelegate*) [[UIApplication sharedApplication] delegate];
    UIViewController *rootView = delegate.window.rootViewController;
    
    //Get to the rootViewController
    while(rootView.presentedViewController)
    {
        rootView = rootView.presentedViewController;
    }
    
    //Set up title and diplayMsg for incoming call alert window
    self.incomingCallAlert = [UIAlertController alertControllerWithTitle:@"Incoming Call" message:displayMsg preferredStyle:UIAlertControllerStyleAlert];
    
    //Define action for accept button on incoming Call Alert
    self.acceptCall = [UIAlertAction
                       actionWithTitle:@"Accept"
                       style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction * action)
                       {
                           //Dismiss the incoming alertwindow
                           [(UIViewController *) self.incomingCallAlert dismissViewControllerAnimated:YES completion:nil];
                           
                           AVAudioSession *audioSession = [AVAudioSession sharedInstance];
                           
                           if (![audioSession setActive:YES error:nil]) {
                               NSLog(@"Failed to create audio Session for incoming call");
                           }
                           
                           if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionMixWithOthers) error:nil]) {
                           }
                           
                           if (self.incomingCall.incomingVideoStatus == CSNetworkVideoSupported) {
                               
                               [self.incomingCall setVideoMode:CSVideoModeSendReceive completionHandler:^(NSError *error) {
                                   
                                   if (error) {
                                       
                                       NSLog(@"%s Error while setting video for call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, self.incomingCall, (long)error.code, error.localizedDescription);
                                   } else {
                                       
                                       NSLog(@"%s Successfully set video for call (%@)", __PRETTY_FUNCTION__, self.incomingCall);
                                   }
                               }];
                           }
                           
                           //Accept call
                           [self.incomingCall accept];
                           
                           //Find Main Story Baord where all View controllers
                           // are present
                           UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                           
                           //Instantiate Navigation Controller of ActiveCallViewController
                           UINavigationController *activeCallNavigationController = (UINavigationController*)[storyboard                                                                                                         instantiateViewControllerWithIdentifier: @"activeCallNavigationController"];
                           ActiveCallViewController *activeController = (ActiveCallViewController *)[activeCallNavigationController topViewController];
                           
                           //Assign Current Call object to incoming Call
                           activeController.currentCall = self.incomingCall;
                           
                           //Present controller on screen
                           [rootView presentViewController:activeCallNavigationController animated:YES completion:nil];
                       }];
    
    //Define action for ignore button on incoming Call Alert
    self.ignoreCall = [UIAlertAction actionWithTitle:@"Ignore" style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
                                                 
                                                 //Dismiss incoming call alert window
                                                 [self.incomingCallAlert dismissViewControllerAnimated:NO completion:nil];
                                                 
                                                 //Ignore Incoming Call
                                                 [self.incomingCall ignore];
                                                 
                                             }];
    
    //Add action buttons on incoming alert window
    [self.incomingCallAlert addAction:self.ignoreCall];
    [self.incomingCallAlert addAction:self.acceptCall];
    
    //Display incoming call alert view window
    [rootView presentViewController:self.incomingCallAlert animated:YES completion:nil];
}


//Sets incoming Call
- (void)setIncomingCallDetails{
    CSCallService *callService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.callService) {
            callService = user.callService;
            break;
        }
    }
    
    for (CSCall *call in callService.calls) {
        if (call.state == CSCallStateAlerting) {
            
            self.incomingCall = call;
            break;
        }
    }
    
    NSLog(@"%s Incoming call from Name:[%@], number:[%@], callType: [%@]", __FUNCTION__, self.incomingCall.remoteDisplayName, self.incomingCall.remoteNumber, (self.incomingCall.incomingVideoStatus==CSNetworkVideoSupported ? @"Video" : @"Audio"));
}

// Dismiss Alert View controller if call is missed call
- (void)didReceiveMissedCall:(NSNotification *)notification {
    
    [self.incomingCallAlert dismissViewControllerAnimated:YES completion:nil];
    
}

@end
