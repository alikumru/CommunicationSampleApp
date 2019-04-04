/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MediaManager.h"
#import "NotificationHelper.h"
#import "ActiveCallViewController.h"

#import <AVFoundation/AVFoundation.h>

@interface MediaManager()
<CSVideoInterfaceDelegate,
CSVideoCapturerDelegate>

@property (nonatomic, weak) CSClient *client;
@property (nonatomic, weak) ActiveCallViewController *viewController;
@property (nonatomic) BOOL localVideoStarted;
@property (nonatomic, readonly) CSMediaServicesInstance *mediaServicesInstance;
@property (nonatomic, readonly) id<CSVideoInterface> videoInterface;

@end

@implementation MediaManager

@synthesize mediaServicesInstance;
@synthesize videoInterface;
@synthesize audioInterface;

- (id)initWithClient: (CSClient *)client {
    if (self = [super init]) {
        self.client = client;

        [self initializeMediaEngine];
        self.localVideoStarted = NO;
    }
    return self;
}

- (void)initializeMediaEngine {
    if (self.client) {
        mediaServicesInstance = self.client.mediaServices;
        videoInterface = mediaServicesInstance.videoInterface;
        audioInterface = mediaServicesInstance.audioInterface;
        
        [videoInterface setDelegate:self];
    }
}

- (void)initVideoView: (UIViewController *)viewController {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    self.viewController = (ActiveCallViewController *)viewController;
}

- (void)prepareSessionWithCategory:(NSString *)category {
    [self prepareSessionWithCategory:category video:NO];
}


- (void)prepareSessionWithCategory:(NSString *)category video:(BOOL)video {
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *audioSessionError = nil;
   
    if ([audioSession.category isEqualToString:category]) {
      
        if ([audioSession.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
            // check mode
            if (![audioSession.mode isEqualToString:(video ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat)]) {

                [audioSession setMode:(video ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat) error:&audioSessionError];
                if (audioSessionError) {

                }
            }
        }
        return; // no change to perform
    }
}


- (void)prepareAudioForCallsWithVideo:(BOOL)video {

    [self prepareSessionWithCategory:AVAudioSessionCategoryPlayAndRecord video:video];
}

- (void)configureAudioSession {

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError* err;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err) {
        NSLog(@"%s Error setting audio category %@", __PRETTY_FUNCTION__, err);
    }
    [audioSession setMode:AVAudioSessionModeVoiceChat error:&err];
    if (err) {
        NSLog(@"%s Error setting audio Mode %@", __PRETTY_FUNCTION__, err);
    }
}

// Start rendering local video preview
- (BOOL)runLocalVideo{
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.localVideoSink setMirrored:YES];
    
    if(!self.videoCapturer) {
        self.videoCapturer = [[CSVideoCapturerIOS alloc] init];
    }
    
    [self.videoCapturer setLocalVideoSink:self.localVideoSink];
    [self.videoCapturer setVideoSink:[self.videoInterface getLocalVideoSink:self.channelId]];
    [self.videoCapturer useVideoCameraAtPosition:CSVideoCameraPositionFront completion:nil];
    
    // start local rendering
    self.viewController.localVideoView.hidden = NO;
    
    return YES;
}

// Start rendering remote video preview
- (void)runRemoteVideo:(CSCall*) call {
    
    //Use first Video Channel
    CSVideoChannel * channel = [[call videoChannels] firstObject];
    
    [[videoInterface getRemoteVideoSource:channel.channelId] setVideoSink:self.remoteVideoSink];
}

// Configure video for outgoing call
- (void)configureVideoForOutgoingCall:(CSCall*) call withVideoMode:(CSVideoMode)videoMode {
    
    __weak CSCall *videoCall = call;
    [call setVideoMode:videoMode completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while configuring video for outgoing call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, videoCall, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while configuring video for outgoing call"] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully configured video for outgoing call (%@)", __PRETTY_FUNCTION__, videoCall);
        }
    }];
}

- (void)updateVideoChannels:(NSArray *)videoChannels {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    if ([videoChannels count] == 0) {
        
        return;
    }
    
    if (!self.localVideoStarted) {
        
        [self runLocalVideo];
    }
    
    CSVideoChannel *videoChannel = videoChannels[0];
    self.channelId = videoChannel.channelId;
    
    if (videoChannel.enabled == YES) {
        
        if (self.viewController.remoteVideoView.hidden == YES) {
            self.viewController.remoteVideoView.hidden = NO;
        }
        
        // Start video rendering if the negotiated video direction is send-receive or receive-only and video rendering is not in progress
        if (videoChannel.negotiatedDirection == CSMediaDirectionSendReceive || videoChannel.negotiatedDirection == CSMediaDirectionReceiveOnly) {
            
            [[videoInterface getRemoteVideoSource:videoChannel.channelId] setVideoSink:self.remoteVideoSink];
            NSLog(@"%s Started video rendering", __PRETTY_FUNCTION__);
        }
        
        // for a held call the media direction is inactive
        if (videoChannel.negotiatedDirection == CSMediaDirectionInactive){
            
            [[videoInterface getRemoteVideoSource:videoChannel.channelId] setVideoSink:nil];
            NSLog(@"%s Stopped video rendering", __PRETTY_FUNCTION__);
        }
        
        // Start video transmission if the negotiated video direction is send-receive or send-only and video transmission is not in progress
        if (videoChannel.negotiatedDirection == CSMediaDirectionSendReceive || videoChannel.negotiatedDirection == CSMediaDirectionSendOnly) {
            
            [self.videoCapturer setVideoSink: [videoInterface getLocalVideoSink: videoChannel.channelId]];
            NSLog(@"%s Started video transmission", __PRETTY_FUNCTION__);
        }
    } else if(videoChannel.enabled == NO) {
        
        if (self.viewController.remoteVideoView.hidden == NO) {
            
            self.viewController.remoteVideoView.hidden = YES;
        }
        
        [[videoInterface getRemoteVideoSource:videoChannel.channelId] setVideoSink:nil];
        [self.videoCapturer setVideoSink: nil];
    }
}

// Add video to an already active audio call
- (void)addVideoToCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self runLocalVideo] == NO) {
        
        NSLog(@"%s Unable to add video", __PRETTY_FUNCTION__);
        return;
    }
    
    self.viewController.remoteVideoView.hidden = NO;
    
    __weak CSCall *videoCall = call;
    [call setVideoMode:videoMode completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while adding video to call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, videoCall, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while adding video to call"] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully added video to call (%@)", __PRETTY_FUNCTION__, videoCall);
        }
    }];
}

// Accept incoming video call
- (void)acceptVideoForCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([self runLocalVideo] == NO) {
        
        NSLog(@"%s Unable to accept video", nil);
        return;
    }
    
    self.viewController.remoteVideoView.hidden = NO;
    
    [call acceptVideo:videoMode completionHandler:^(NSError *error) {
        
        if (error) {
            
            self.viewController.remoteVideoView.hidden = YES;
            NSLog(@"%s Error while accepting video of incoming call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, call, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while accepting video of incoming call"] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully accepted video of incoming call (%@)", __PRETTY_FUNCTION__, call);
        }
    }];
}

// Remove video from an active video, call will be audio-only after this
- (void)removeVideoFromCall:(CSCall*)call {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    self.viewController.remoteVideoView.hidden = YES;
    
    __weak CSCall *videoCall = call;
    [call setVideoMode:CSVideoModeNone completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while removing video of call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, videoCall, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while removing video of call"] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully removed video of call (%@)", __PRETTY_FUNCTION__, videoCall);
        }
    }];
    
    CSVideoChannel * channel = [[call videoChannels] firstObject];
    
    [[videoInterface getRemoteVideoSource:channel.channelId] setVideoSink:nil];
    
    [self.localVideoSink handleVideoFrame: nil];
    
    [self.videoCapturer setVideoSink:nil];
    [self.videoCapturer useVideoCameraAtPosition:(CSVideoCameraPosition)nil completion:nil];
    
    self.viewController.localVideoView.hidden = YES;
}

// Update direction of video transmission
- (void)updateVideoOfCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    
    __weak CSCall *videoCall = call;
    // Update video with requested CSVideoMode
    [call setVideoMode:videoMode completionHandler:^(NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while updating video of call (%@). Error[%ld] - %@", __PRETTY_FUNCTION__, videoCall, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while updating video of call"] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Successfully updated video of call (%@)", __PRETTY_FUNCTION__, videoCall);
        }
    }];
}

- (void)printMicrophonesList {
    NSArray *microphones = [audioInterface availableRecordDevices];
    
    if ([microphones count] == 0) {
        NSLog(@"%s No microphones available", __PRETTY_FUNCTION__);
    }
    else {
        NSLog(@"%s Microphones:", __PRETTY_FUNCTION__);
        uint count = 0;
        for (CSMicrophoneDevice* mc in microphones) {
            if ([mc.guid isEqualToString:[audioInterface activeMicrophone].guid]) {
                NSLog(@"%s * [%d] %@ (%@)", __PRETTY_FUNCTION__, count, mc.name, mc.guid);
            }
            else {
                NSLog(@"%s   [%d] %@ (%@)", __PRETTY_FUNCTION__, count, mc.name, mc.guid);
            }
            count++;
        }
    }
}

- (void)setMicrophone:(CSMicrophoneDevice*)microphone {
    [audioInterface setUserRequestedMicrophone:microphone];
}

- (void)printSpeakersList {
    NSArray *speakers = [audioInterface availablePlayDevices];
    
    if ([speakers count] == 0) {
        NSLog(@"%s No speakers available", __PRETTY_FUNCTION__, nil);
    }
    else {
        NSLog(@"%s Speakers:", __PRETTY_FUNCTION__);
        uint count = 0;
        for (CSSpeakerDevice* speaker in speakers) {
            if ([speaker.guid isEqualToString:[audioInterface activeSpeaker].guid]) {
                NSLog(@"%s * [%d] %@ (%@)", __PRETTY_FUNCTION__, count, speaker.name, speaker.guid);
            }
            else {
                NSLog(@"%s   [%d] %@ (%@)", __PRETTY_FUNCTION__, count, speaker.name, speaker.guid);
            }
            count++;
        }
    }
}

- (void)setSpeaker:(CSSpeakerDevice*)speaker {
    
    if(speaker){
        self.audioInterface.userRequestedDevice = speaker;
    } else {
        
        self.audioInterface.userRequestedDevice = [self.audioInterface.availableAudioDevices
                                                   objectAtIndex:CSAudioDeviceDefault];
    }
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSVideoInterfaceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)videoInterface:(id<CSVideoInterface>)videoInterface didChangeRemoteFrameWidth:(int)frameWidth frameHeight:(int)frameHeight forChannelId:(int)channelId {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)videoInterface:(id<CSVideoInterface>)videoInterface didChangeLocalFrameWidth:(int)frameWidth frameHeight:(int)frameHeight {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)videoInterface:(id<CSVideoInterface>)videoInterface onNoFramesFromCameraFor:(int)durationInSec {
    
    NSLog(@"%s No frames from camera for %d seconds", __PRETTY_FUNCTION__, durationInSec);
}

- (void)videoInterface:(id<CSVideoInterface>)videoInterface onPacketTimeOutForWebRTCChannelId:(int)nWebRTCChannelId timeout:(unsigned int)timeout forChannelId:(int)nChannelId {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}


////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSVideoCapturerDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)videoCapturerRuntimeError:(NSError *)error {
    
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
}

- (void)videoCapturerWasInterrupted {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)videoCapturerInterruptionEnded {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

////////////////////////////////////////////////


////////////////////////////////////////////////

- (BOOL)startPlayingTone:(id<CSAudioFilePlayerListener>)audioFilePlayerListener toneToBePlayed: (CSAudioTone)tone playInLoop:(BOOL)loop{
    
    BOOL bResult = NO;
    
    // Stop any previous playback of tone
    [self stopPlayingTone];
    
    self.audioFilePlayer = [audioInterface createAudioFilePlayer:audioFilePlayerListener];
    if ( self.audioFilePlayer ) {
        
        [self.audioFilePlayer setTone:tone];
        [self.audioFilePlayer setIsLoop:loop];
        bResult = [self.audioFilePlayer startPlaying];
    }
    return bResult;
}

- (BOOL)isPlayingTone {
    
    BOOL bResult = NO;
    
    if ( self.audioFilePlayer ) {
        
        bResult = [self.audioFilePlayer isPlaying];
    }
    return bResult;
}


- (BOOL)stopPlayingTone {
    
    BOOL bResult = NO;
    
    if ( [self isPlayingTone] ) {
        
        bResult = [self.audioFilePlayer stopPlaying];
    }
    return bResult;
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSAudioFilePlayerListener

////////////////////////////////////////////////////////////////////////////////

- (void)audioFileDidStartPlaying:(id<CSAudioFilePlayer>)player {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)audioFileDidStopPlaying:(id<CSAudioFilePlayer>)player {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

////////////////////////////////////////////////////////////////////////////////

@end
