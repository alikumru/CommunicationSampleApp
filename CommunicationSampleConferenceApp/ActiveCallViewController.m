/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ActiveCallViewController.h"
#import "ConferenceControlViewController.h"

@interface ActiveCallViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;
@property (nonatomic, weak) NSTimer *callTimer;
@property (nonatomic) BOOL viewInitialized;
@property (nonatomic, strong) MediaManager *mediaManager;
@property (nonatomic, weak) CSCollaboration *collaboration;
@property (nonatomic, weak) CSContentSharing *contentSharing;

@end

@implementation ActiveCallViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self setBorderWidth:self.endCallBtn];
    [self setBorderWidth:self.holdCallBtn];
    
    self.participantList.layer.borderWidth = 0.5f;
    
    self.title = @"Active Call";
    
    NSLog(@"%s Received call object from segue: [%@]", __PRETTY_FUNCTION__, self.currentCall);
    
    // Register for call state change notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kRefreshActiveCallWindowNotification object:nil];
    
    // Display current call status
    self.callState.text = @"";
    
    self.mediaManager = [SDKManager getInstance].mediaManager;
    
    if(self.currentCall.isConference) {
        
        NSLog(@"%s Call is Conference call, populate participant list", __PRETTY_FUNCTION__);
        
        NSArray *participantsNames = [self.currentCall.conference.participants valueForKey:@"displayName"];
        self.participantList.text = [participantsNames componentsJoinedByString:@"\n"];
        
        self.conferenceControlBtnLabel.hidden = !self.currentCall.conference.moderationCapability.allowed;
        
    } else if(self.currentCall.callerIdentityPrivate) {
        
        NSLog(@"%s Call identitiy is private", __PRETTY_FUNCTION__);
        self.participantList.text = @"Restricted";
    } else {
        
        NSLog(@"%s Update caller display name", __PRETTY_FUNCTION__);
        self.participantList.text = self.currentCall.remoteDisplayName;
    }
    
    if (self.mediaManager.audioInterface.isSpeakerConnected) {
        
        NSLog(@"%s AudioDevice: Only Speaker device is available", __PRETTY_FUNCTION__);
        self.speakerPhoneSwitch.enabled = NO;
        [self.speakerPhoneSwitch setOn:YES];
    } else {
        
        self.speakerPhoneSwitch.enabled = YES;
        [self.speakerPhoneSwitch setOn:NO];
        if (self.mediaManager.audioInterface.isHeadsetConnected) {
            
            NSLog(@"%s AudioDevice: Wired headset is connected to phone", __PRETTY_FUNCTION__);
        } else if (self.mediaManager.audioInterface.isBluetoothConnected) {
            
            NSLog(@"%s AudioDevice: Bluetooth is connected to phone", __PRETTY_FUNCTION__);
        }
    }
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshActiveCallWindowNotification object:nil];
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {

}

- (void)viewDidDisappear:(BOOL)animated {
    
    [super viewDidDisappear:YES];
    //Release video resources
    [self deallocViews];
}

- (void)setBorderWidth:(UIButton *)btn {
    
    btn.layer.borderWidth = 0.5f;
    btn.layer.borderColor = [[UIColor blackColor]CGColor];
}

- (IBAction)endCallBtnClicked:(id)sender {

    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[SDKManager getInstance] endCall: [self currentCall]];
    [self dismissViewControllerAnimated:YES completion:^{NSLog(@"%s Controller Dismiss", __PRETTY_FUNCTION__);}];
}

- (IBAction)holdCallBtnClicked:(id)sender {
	
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[SDKManager getInstance] holdOrUnHoldCall:[self currentCall]];

}

- (IBAction)muteSwitchValueChanged:(id)sender {
    
    if (!self.currentCall.audioMuted) {
        
        if(self.currentCall.muteCapability.allowed) {
            
            NSLog(@"%s Call audio can be muted", __PRETTY_FUNCTION__);
            
            [self.currentCall muteAudio: YES completionHandler:^(NSError *error) {
                
                if(error) {
                    
                    [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while muting audio of call, callId: [%lu]", (long)self.currentCall.callId] TAG:__PRETTY_FUNCTION__];
                } else {
                    
                    NSLog(@"%s Audio Mute succesfful for call, callId: [%lu]", __PRETTY_FUNCTION__, (long)self.currentCall.callId);
                }
            }];
        } else {
            
            NSLog(@"%s Call audio cannot be muted", __PRETTY_FUNCTION__);
        }
    } else {
        
        if(self.currentCall.unmuteCapability.allowed && self.currentCall.audioMuted) {
            
            NSLog(@"%s Call audio can be unmuted", __PRETTY_FUNCTION__);
            
            [self.currentCall muteAudio:NO completionHandler:^(NSError *error) {
                
                if(error) {
                    
                    [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while muting Audio of the call, callId: [%ld]", (long)self.currentCall.callId] TAG: __PRETTY_FUNCTION__];
                } else {
                    
                    NSLog(@"%s Audio of call muted successfully, callId:[%lu]", __PRETTY_FUNCTION__, (long)self.currentCall.callId);
                }
            }];
        } else {
            
            NSLog(@"%s Call audio cannot be unmuted", __PRETTY_FUNCTION__);
        }
    }
}

- (IBAction)speakerPhoneSwitchValueChanged:(id)sender {
    
    if (self.speakerPhoneSwitch.on) {
        
        for (CSSpeakerDevice *speaker in [[self.mediaManager audioInterface] availableAudioDevices]) {
            
            if ([speaker.name isEqualToString:@"AudioDeviceSpeaker"]) {
                
                [self.mediaManager setSpeaker:speaker];
                break;
            }
        }
    }else {
        
        [self.mediaManager setSpeaker:nil];
    }
}

- (void)refresh:(NSNotification *)notification {
    
    if (self.currentCall.videoChannels.count != 0) {
        
        NSLog(@"%s call has Video", __PRETTY_FUNCTION__);
        [self initViews];
    } else {
        
        NSLog(@"%s call doesn't have Video", __PRETTY_FUNCTION__);
        [self deallocViews];
    }
    
    NSString *state = nil;
    
    // Determine current call state
    switch (self.currentCall.state) {
        case CSCallStateIdle:
            state = @"Idle";
            break;
        case CSCallStateInitiating:
            state = @"Initiating";
            break;
        case CSCallStateAlerting:
            state = @"Alerting";
            break;
        case CSCallStateRemoteAlerting:
            state = @"Remote Alerting";
            break;
        case CSCallStateEstablished:
        {
            state = @"Established";
            [self.callTimer invalidate];
            
            self.callTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                              target:self selector:@selector(callTimer:)
                                                            userInfo:nil repeats:YES];
            break;
        }
        case CSCallStateHolding:
            state = @"Holding";
            break;
        case CSCallStateHeld:
            state = @"Held";
            break;
        case CSCallStateUnholding:
            state = @"Unholding";
            break;
        case CSCallStateVideoUpdating:
            state = @"Video Updating";
            break;
        case CSCallStateTransferring:
            state = @"Transferring";
            break;
        case CSCallStateBeingTransferred:
            state = @"Being Transferred";
            break;
        case CSCallStateIgnored:
            state = @"Ignored";
            break;
        case CSCallStateFailed:
            state = @"Failed";
            //End Call Timer
            
            [self.callTimer invalidate];
            [self deallocViews];
            break;
        case CSCallStateEnding:
            state = @"Ending";
            break;
        case CSCallStateEnded:
        {
            state = @"Ended";
            [self.callTimer invalidate];
            [self deallocViews];
            [self dismissViewControllerAnimated:YES completion:^{NSLog(@"%s controller dismiss", __PRETTY_FUNCTION__);}];
            break;
        }
        case CSCallStateRenegotiating:
            state = @"Renegotiating";
            break;
        case CSCallStateFarEndRenegotiating:
            state = @"Far end Renegotiating";
            break;
        default:
            state = @"Unknown";
            break;
    }
    
    // Update current call state on UI
    self.callState.text = [NSString stringWithFormat:@"%@", state];
    
    if(self.currentCall.isConference) {
        
        //Upon refresh reset participant List to Null.
        self.participantList.text = @"";
        NSLog(@"%s Call is Conference call, populate participant list", __PRETTY_FUNCTION__);
        NSArray *participantsNames = [self.currentCall.conference.participants valueForKey:@"displayName"];
        self.participantList.text = [participantsNames componentsJoinedByString:@"\n"];
        
        self.conferenceControlBtnLabel.hidden = !self.currentCall.conference.moderationCapability.allowed;
    } else if(self.currentCall.callerIdentityPrivate) {
        
        NSLog(@"%s Call identitiy is private", __PRETTY_FUNCTION__);
        self.participantList.text = @"Restricted";
    } else {
        
        NSLog(@"%s Update caller display name", __PRETTY_FUNCTION__);
        self.participantList.text = self.currentCall.remoteDisplayName;
    }
}

- (NSString *)callTimerAsFormattedString {
    
    // Get elapsed time since call was established
    NSTimeInterval interval = - [self.currentCall.establishedDate timeIntervalSinceNow];
    NSString *intervalString = [[NSDateComponentsFormatter new] stringFromTimeInterval: interval];
    
    NSString *callTimerFormat;
    
    //Set correct format to hh:mm:ss
    switch(intervalString.length){
        case 1:
            callTimerFormat = @"00:00:0%@";
            break;
            
        case 2:
            callTimerFormat = @"00:00:%@";
            break;
            
        case 4:
            callTimerFormat = @"00:0%@";
            break;
            
        case 5:
            callTimerFormat = @"00:%@";
            break;
            
        case 7:
            callTimerFormat = @"0%@";
            break;
            
        default :
            callTimerFormat = @"%@";
    }
    
    return [NSString stringWithFormat:callTimerFormat, intervalString];
}

- (void)callTimer:(NSTimer*)theTimer {
    
    self.callDuration.text = [self callTimerAsFormattedString];
}

- (void)initViews {
    
    // Perform initialization only once
    if (!self.viewInitialized) {
        
        [self.mediaManager initVideoView:self];
        self.viewInitialized = YES;
        
        self.mediaManager.localVideoSink = (CSVideoRendererIOS *) self.localVideoView.layer;
        self.mediaManager.remoteVideoSink = (CSVideoRendererIOS *) self.remoteVideoView.layer;
        
        // Show local video preview while is active
        if((self.currentCall.state != CSCallStateEnding) || (self.currentCall.state != CSCallStateEnded)) {
            
            [self.mediaManager runLocalVideo];
        }
    }
    // Show remote video preview when call is established
    if ([self.currentCall state] == CSCallStateEstablished) {
        
        [self.mediaManager.remoteVideoSink handleVideoFrame:nil];
        [self.mediaManager runRemoteVideo:self.currentCall];
    }
    
    // show labels on window
    self.remoteVideoLabel.hidden = NO;
    self.localVideoLabel.hidden = NO;
    
    // show local video preview
    self.localVideoView.hidden = NO;
    self.remoteVideoView.hidden = NO;
}

- (void)deallocViews{
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    // Hide local and remote video previews
    self.localVideoView.hidden = YES;
    self.remoteVideoView.hidden = YES;
    self.remoteVideoLabel.hidden = YES;
    self.localVideoLabel.hidden = YES;
    
    // Release video
    [self.mediaManager.localVideoSink handleVideoFrame:nil];
    [self.mediaManager.videoCapturer setVideoSink:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    
    ConferenceControlViewController *viewController = segue.destinationViewController;
    
    if ([segue.identifier isEqualToString:@"conferenceControlSegue"]) {
        
        viewController.conferenceCall = self.currentCall.conference;
    }
}

@end

