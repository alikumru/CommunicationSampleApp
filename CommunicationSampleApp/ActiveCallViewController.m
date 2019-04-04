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
@property (nonatomic, weak) ContentSharingViewController *sharingViewController;

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collaborationStartedNotification:) name:kCollaborationStartedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentSharingStarted:) name:kContentSharingStartedByParticipant object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ContentSharingViewClosed:) name:kContentSharingViewClosed object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contentSharingEnded:) name:kContentSharingEnded object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collabSessionEndedRemotely:) name:kCollaborationSessionEndedRemotely object:nil];
    
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
    
    //Register for DTMF text field edit notifications
    [self.dtmf addTarget:self action:@selector(dtmfTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    if (self.mediaManager.audioInterface.isSpeakerConnected) {
        
        NSLog(@"%s AudioDevice: Only Speaker device is available", __PRETTY_FUNCTION__);
        self.speakerPhoneBtn.enabled = NO;
        [self.speakerPhoneBtn setOn:YES];
    } else {
        
        self.speakerPhoneBtn.enabled = YES;
        [self.speakerPhoneBtn setOn:NO];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCollaborationStartedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContentSharingStartedByParticipant object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContentSharingViewClosed object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kContentSharingEnded object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCollaborationSessionEndedRemotely object:nil];
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    
    [self.dtmf resignFirstResponder];
}

- (void)viewDidDisappear:(BOOL)animated {
    
    [super viewDidDisappear:YES];
    //Release video resources
    [self deallocViews];
}

- (void)ContentSharingViewClosed : (NSNotification *) notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.sharingViewController = nil;
    self.collaborationBtnLabel.hidden = NO;
}

- (void)contentSharingEnded : (NSNotification *) notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.sharingViewController = nil;
    self.collaborationBtnLabel.hidden = YES;
}

- (void)setBorderWidth:(UIButton *)btn {
    
    btn.layer.borderWidth = 0.5f;
    btn.layer.borderColor = [[UIColor blackColor]CGColor];
}

- (IBAction)endCallBtn:(id)sender {

    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[SDKManager getInstance] endCall: [self currentCall]];
    [self dismissViewControllerAnimated:YES completion:^{NSLog(@"%s Controller Dismiss", __PRETTY_FUNCTION__);}];
}

- (IBAction)holdCallBtn:(id)sender {
	
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[SDKManager getInstance] holdOrUnHoldCall:[self currentCall]];

}


//Presents Content Sharing
- (void)displayCollaboration {
    
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    self.sharingViewController = [storyBoard instantiateViewControllerWithIdentifier:@"ContentSharingViewController"];
    self.sharingViewController.contentSharing = self.contentSharing;
    self.sharingViewController.collab = self.collaboration;
    self.collaborationBtnLabel.hidden = NO;
    [self.navigationController pushViewController:self.sharingViewController animated:YES];
}

- (IBAction)collaborationBtn:(id)sender {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self displayCollaboration];
}

- (void)contentSharingStarted :(NSNotification *)notification {
    
    if (notification.object) {
        
        self.contentSharing = notification.object;
        [self displayCollaboration];
    }
}

- (void)collaborationStartedNotification:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.collaboration = notification.object;
}

- (void)collabSessionEndedRemotely:(NSNotification *)notification {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.collaborationBtnLabel.hidden = YES;
}

- (IBAction)muteCallBtn:(id)sender {
    
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

- (IBAction)speakerPhoneBtn:(id)sender {
    
    if (self.speakerPhoneBtn.on) {
        
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

- (void)dtmfTextFieldDidChange:(NSNotification *)obj {
    
    if (self.currentCall.sendDigitCapability.allowed) {
        
        if (self.dtmf.text.length > 0) {
            
            NSString *digit = [self.dtmf.text substringFromIndex:self.dtmf.text.length - 1];
            NSLog(@"%s Send DTMF DIGIT: [%@]", __PRETTY_FUNCTION__, digit);
            
            NSInteger digitCode = -1;
            
            if (digit.integerValue == 0) {
                
                if ([digit compare:@"0"] == NSOrderedSame) {
                    
                    digitCode = 0;
                } else if ([digit compare:@"*"] == NSOrderedSame) {
                    
                    digitCode = 10;
                } else if ([digit compare:@"#"] == NSOrderedSame) {
                    
                    digitCode = 11;
                } else if ([digit compare:@"a" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                    
                    digitCode = 11;
                } else if ([digit compare:@"b" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                    
                    digitCode = 12;
                } else if ([digit compare:@"c" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                    
                    digitCode = 13;
                } else if ([digit compare:@"d" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
                    
                    digitCode = 14;
                }
            } else {
                digitCode = digit.integerValue;
            }
            
            NSLog(@"Digit Code = %ld", (long)digitCode);
            
            if((digitCode >= CSDTMFToneZero) && (digitCode <=CSDTMFToneNine)) {
                
                [self.currentCall sendDigit:digitCode];
            } else {
                switch (digitCode) {
                    case 10:
                        [self.currentCall sendDigit:CSDTMFToneStar];
                        break;
                    case 11:
                        [self.currentCall sendDigit:CSDTMFTonePound];
                        break;
                    case 12:
                        [self.currentCall sendDigit:CSDTMFToneA];
                        break;
                    case 13:
                        [self.currentCall sendDigit:CSDTMFToneB];
                        break;
                    case 14:
                        [self.currentCall sendDigit:CSDTMFToneC];
                        break;
                    case 15:
                        [self.currentCall sendDigit:CSDTMFToneD];
                        break;
                    default:
                        NSLog(@"Not a valid DTMF character");
                        break;
                }
            }
        }
    } else {
        
        NSLog(@"%s Client does not have capability to send DTMF", __PRETTY_FUNCTION__);
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

