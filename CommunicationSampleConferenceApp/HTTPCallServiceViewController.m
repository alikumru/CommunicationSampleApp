/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "HTTPCallServiceViewController.h"
#import "SDKManager.h"
#import "CSCall+Additions.h"
#import "ActiveCallViewController.h"
#import "NotificationHelper.h"
#import "ConfigData.h"

@interface HTTPCallServiceViewController ()

@property (nonatomic) CSCall *currentCall;
@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation HTTPCallServiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Set delegate to hide keyboard on iPhone
    self.conferenceURLTextField.delegate = self;
    self.displayNameTextField.delegate = self;
    self.conferenceUsernameTextField.delegate = self;
    self.conferencePasswordTextField.delegate = self;
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
    
    // Restore UI from saved configuration
    [self restoreConfiguration];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kRefreshWindowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidRegister:) name:kUserDidRegisterNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDidFailToRegister:) name:kUserDidFailToRegisterNotification object:nil];
    
    NSLog(@"%s start user auto-login", __PRETTY_FUNCTION__);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        // Create user in async task
        [[SDKManager getInstance] setupClient];
    });
}

- (void)dealloc{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshWindowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kUserDidRegisterNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kUserDidFailToRegisterNotification object:nil];

    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    [self.conferenceURLTextField resignFirstResponder];
}

- (void)setBorderWidth:(UIButton *)btn
{
    btn.layer.borderWidth = 0.5f;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    UINavigationController *navigationController = [segue destinationViewController];
    if (![navigationController isKindOfClass:[UINavigationController class]]) {
        return;
    }
    ActiveCallViewController *transferViewController = (ActiveCallViewController *)[navigationController topViewController];
    
    if ([segue.identifier isEqualToString:@"audioCallSegue"]) {
        NSLog(@"%s Perform Audio call segue", __PRETTY_FUNCTION__);
        [self createCallWithCompletionHandler:^(NSError *error) {
            if (error == nil) {
                NSLog(@"%s currentCall = [%@]", __PRETTY_FUNCTION__, self.currentCall);
                [self audioCall];
                transferViewController.currentCall = self.currentCall;
            } else {
                [transferViewController dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    } else if ([segue.identifier isEqualToString:@"videoCallSegue"]) {
        NSLog(@"%s Perform Video call segue", __PRETTY_FUNCTION__);
        [self createCallWithCompletionHandler:^(NSError *error) {
            if (error == nil) {
                NSLog(@"%s currentCall = [%@]", __PRETTY_FUNCTION__, self.currentCall);
                [self videoCall];
                transferViewController.currentCall = self.currentCall;
            } else {
                [transferViewController dismissViewControllerAnimated:YES completion:nil];
            }
        }];
    }
}

- (void)audioCall {
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    if (![audioSession setActive:YES error:nil]) {
        NSLog(@"Failed to create audio Session for audio call");
    }
    
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionMixWithOthers) error:nil]) {
    }
    
    [self.currentCall start];
    
}

- (void)videoCall {
    
    [[SDKManager getInstance].mediaManager configureVideoForOutgoingCall:self.currentCall withVideoMode:CSVideoModeSendReceive];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    
    if (![audioSession setActive:YES error:nil]) {
        NSLog(@"Failed to create audio Session for video call");
    }
    
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:(AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionMixWithOthers) error:nil]) {
    }
    
    [self.currentCall start];
}

- (void)createCallWithCompletionHandler:(void(^)(NSError*))completionHandler {
    // Update configuration with UI data
    ConfigData *configuration = [self saveConfiguration];
    
    // Retrieve the token and other meeting details
    [self.unifiedPortalService
     requestToJoinMeetingWithConfiguration: configuration.unifiedPortalConfiguration
     conferenceId: configuration.conferenceID
     userName: configuration.displayName
     presentationOnlyMode: NO
     callbackNumber: @""
     oneTimePin: @""
     completionHandler:
     ^(CSUnifiedPortalMeetingInfo *meetingInfo, NSError *error)
     {
         if(error != nil)
         {
             self.messageLabel.text = [NSString stringWithFormat:@"Join failed with error: %@", [error localizedDescription]];
         }
         else
         {
             self.messageLabel.text = @"";
             
             CSCallCreationInfo *callCreationInfo = [[CSCallCreationInfo alloc] init];
             callCreationInfo.callType             = CSCallTypeHttpMeetme;
             callCreationInfo.conferenceId         = configuration.conferenceID;
             callCreationInfo.conferencePasscode   = @"";
             callCreationInfo.portalToken          = meetingInfo.portalToken;
             callCreationInfo.uccpURL              = meetingInfo.uccpURL;
             callCreationInfo.serviceGatewayURL    = meetingInfo.serviceGatewayURL;
             callCreationInfo.portalURL            = configuration.portalURL;
             callCreationInfo.meetmeUserName       = configuration.displayName;
             callCreationInfo.presentationOnlyMode = NO;
             
             CSCall *call;
             call = [self.callService createCallWithInfo: callCreationInfo];
             call.remoteAddress = configuration.conferenceID;
             
             self.currentCall = call;
         }
         completionHandler(error);
     }];
}

- (IBAction)guestLoginSwitchValueChanged:(id)sender {
    BOOL loginAsGuest = self.guestLoginSwitch.on;
    
    self.displayNameLabel.enabled = loginAsGuest;
    self.displayNameTextField.enabled = loginAsGuest;
    self.conferenceUsernameLabel.enabled = !loginAsGuest;
    self.conferenceUsernameTextField.enabled = !loginAsGuest;
    self.conferencePasswordLabel.enabled = !loginAsGuest;
    self.conferencePasswordTextField.enabled = !loginAsGuest;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    if (textField == self.conferenceURLTextField) {
        
        [textField resignFirstResponder];
        if (self.guestLoginSwitch.on) {
            [self.displayNameTextField becomeFirstResponder];
        } else {
            [self.conferenceUsernameTextField becomeFirstResponder];
        }
    } else if (textField == self.conferenceUsernameTextField) {

        [textField resignFirstResponder];
        [self.conferencePasswordTextField becomeFirstResponder];
    } else {
        
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)refresh:(NSNotification *)notification {
    
    CSUser *user = [SDKManager getInstance].user;
    if (user) {
        self.callService = user.callService;
        self.unifiedPortalService = user.unifiedPortalService;
    }
    
    if (self.unifiedPortalService == nil) {
        self.makeVideoCallLabel.hidden = YES;
        self.makeAudioCallLabel.hidden = YES;
        self.messageLabel.text = @"Unified Portal Service is not available";
    }
}

- (void)userDidRegister:(NSNotification *)notification  {
    self.makeVideoCallLabel.hidden = NO;
    self.makeAudioCallLabel.hidden = NO;
    self.messageLabel.text = @"";
}

- (void)userDidFailToRegister:(NSNotification *)notification  {
    self.makeVideoCallLabel.hidden = YES;
    self.makeAudioCallLabel.hidden = YES;
    self.messageLabel.text = @"Unified Portal Service is not available";
}

- (void)restoreConfiguration {
    ConfigData *configuration = [ConfigData getInstance];
    self.guestLoginSwitch.on = configuration.loginAsGuest;
    self.conferenceURLTextField.text = configuration.conferenceURL;
    self.conferenceUsernameTextField.text = configuration.conferenceUsername;
    self.conferenceUsernameTextField.enabled = !configuration.loginAsGuest;
    self.conferencePasswordTextField.text = configuration.conferencePassword;
    self.conferencePasswordTextField.enabled = !configuration.loginAsGuest;
    self.displayNameTextField.text = configuration.displayName;
    self.displayNameTextField.enabled = configuration.loginAsGuest;
}

- (ConfigData *)saveConfiguration {
    ConfigData *configuration = [ConfigData getInstance];
    configuration.conferenceURL = self.conferenceURLTextField.text;
    configuration.loginAsGuest = self.guestLoginSwitch.on;
    configuration.displayName = (self.displayNameTextField.text.length > 0)? self.displayNameTextField.text : @"SampleConferenceAppUser";
    configuration.conferenceUsername = self.conferenceUsernameTextField.text;
    configuration.conferencePassword = self.conferencePasswordTextField.text;
    [configuration saveConfiguration];
    return configuration;
}

@end

