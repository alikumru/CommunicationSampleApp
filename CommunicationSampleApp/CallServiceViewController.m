/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "CallServiceViewController.h"
#import "SDKManager.h"
#import "CSCall+Additions.h"
#import "ActiveCallViewController.h"
#import "NotificationHelper.h"

@interface CallServiceViewController ()

@property (nonatomic) CSCall *currentCall;
@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation CallServiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.callService) {
            self.callService = user.callService;
            self.callFeatureService = user.callFeatureService;
            break;
        }
    }
    
    NSLog(@"%s video: [%@] voip: [%@]", __PRETTY_FUNCTION__, self.callService.videoCapability.allowed?@"Yes":@"No", self.callService.voipCallingCapability.allowed?@"Yes":@"No");
    
    // Check if video capability is present for currently registered user
    self.makeVideoCallLabel.hidden = !self.callService.videoCapability.allowed;
    
    // Check if voip calling capability is present for currently registered user
    self.makeAudioCallLabel.hidden = !self.callService.voipCallingCapability.allowed;
    
    // Check if Send All Calls feature is configured on the extension
    if (self.callFeatureService.sendAllCallsCapability.allowed) {
        
        self.sendAllCallsSwitch.on = self.callFeatureService.sendAllCallsEnabled;
    } else {
        
        // Send All Calls is not configured for extension
        NSLog(@"%s Send All Calls is not configured for extension", __PRETTY_FUNCTION__);
        self.sendAllCallsSwitch.enabled = NO;
    }
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc{
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    [self.numberToCall resignFirstResponder];
}

- (void)setBorderWidth:(UIButton *)btn
{
    btn.layer.borderWidth = 0.5f;
}

- (IBAction)sendAllCallsBtn:(id)sender {
    
    if (self.callFeatureService.sendAllCallsEnabled) {
        
        [self.callFeatureService setSendAllCallsEnabled:NO completionHandler: ^(NSError *error) {
            
            if (error) {
                
                NSLog(@"%s Cannot disable Send All Calls, Error code [%ld] - %@",__PRETTY_FUNCTION__ , (long)error.code, error.localizedDescription);
                [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Cannot disable Send All Calls, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                [self.sendAllCallsSwitch setOn:YES];
            } else {
                
                NSLog(@"%s Successfully disabled Send All Calls", __PRETTY_FUNCTION__);
                [self.sendAllCallsSwitch setOn:NO];
            }
        }];
    } else {
        
        [self.callFeatureService setSendAllCallsEnabled:YES completionHandler: ^(NSError *error) {
            
            if (error) {
                
                NSLog(@"%s Cannot enable Send All Calls, Error code [%ld] - %@",__PRETTY_FUNCTION__ , (long)error.code, error.localizedDescription);
                [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Cannot enable Send All Calls, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                [self.sendAllCallsSwitch setOn:NO];
            } else {
                
                NSLog(@"%s Successfully enabled Send All Calls", __PRETTY_FUNCTION__);
                [self.sendAllCallsSwitch setOn:YES];
            }
        }];
    }
    
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *navigationController = [segue destinationViewController];
    ActiveCallViewController *transferViewController = (ActiveCallViewController *)[navigationController topViewController];
    
    if([segue.identifier isEqualToString:@"audioCallSegue"]) {
        
        [self audioCall];
        NSLog(@"%s Perform Audio call segue", __PRETTY_FUNCTION__);
        NSLog(@"%s currentCall = [%@]", __PRETTY_FUNCTION__, self.currentCall);
        transferViewController.currentCall = self.currentCall;
    } else if([segue.identifier isEqualToString:@"videoCallSegue"]) {
        
        [self videoCall];
        NSLog(@"%s Perform Video call segue", __PRETTY_FUNCTION__);
        NSLog(@"%s currentCall = [%@]", __PRETTY_FUNCTION__, self.currentCall);
        transferViewController.currentCall = self.currentCall;
    }
}

- (void)audioCall {
    
    NSString *callingNumber = self.numberToCall.text;
    
    CSCallService *callService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.callService) {
            callService = user.callService;
            break;
        }
    }
    NSLog(@"%s- audio calling number: [%@]", __PRETTY_FUNCTION__, callingNumber);
    
    CSCall *call = [callService createCall];
    
    call.remoteAddress = callingNumber;
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    if (![audioSession setActive:YES error:nil]) {
        NSLog(@"Failed to create audio Session for audio call");
    }
    
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionMixWithOthers) error:nil]) {
    }
    NSLog(@"%s audio call: [%@] currentCall: [%@]", __PRETTY_FUNCTION__, call, self.currentCall);
    
    [[SDKManager getInstance] startCall:call];
    
    // Save the current call's object for operations
    self.currentCall = call;
    NSLog(@"%s audio call: [%@] currentCall: [%@]", __PRETTY_FUNCTION__, call, self.currentCall);
}

- (void)videoCall {
    
    NSString *callingNumber = self.numberToCall.text;
    
    CSCallService *callService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        if (user.callService) {
            callService = user.callService;
            break;
        }
    }
    NSLog(@"%s- video calling number: %@", __PRETTY_FUNCTION__, callingNumber);
    
    CSCall *call = [callService createCall];
    call.remoteAddress = callingNumber;
    
    [[SDKManager getInstance].mediaManager configureVideoForOutgoingCall:call withVideoMode:CSVideoModeSendReceive];
    
    
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    if (![audioSession setActive:YES error:nil]) {
        NSLog(@"Failed to create audio Session for video call");
    }
    
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionMixWithOthers) error:nil]) {
    }
    
    [call start];
    
    // Save the current call's object for operations
    self.currentCall = call;
    
    NSLog(@"%s video call: [%@] currentCall: [%@]", __PRETTY_FUNCTION__, call, self.currentCall);
}

@end

