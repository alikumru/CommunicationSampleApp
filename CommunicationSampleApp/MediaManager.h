/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>

@interface MediaManager : NSObject<CSAudioFilePlayerListener>

@property (nonatomic, readonly) id<CSAudioInterface> audioInterface;
@property (nonatomic, strong) CSVideoCapturerIOS *videoCapturer;
@property (nonatomic, strong) CSVideoRendererIOS *localVideoSink;
@property (nonatomic, strong) CSVideoRendererIOS *remoteVideoSink;
@property (nonatomic) int channelId;
@property (strong, nonatomic) id<CSAudioFilePlayer> audioFilePlayer;

- (instancetype)init __unavailable;
- (id)initWithClient:(CSClient*)client;
- (void)initVideoView: (UIViewController *)viewController;
- (BOOL)runLocalVideo;
- (void)runRemoteVideo:(CSCall*)call;

- (void)configureVideoForOutgoingCall:(CSCall*) call withVideoMode:(CSVideoMode)videoMode;
- (void)addVideoToCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode;
- (void)removeVideoFromCall:(CSCall*)call;
- (void)updateVideoOfCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode;
- (void)acceptVideoForCall:(CSCall*)call withVideoMode:(CSVideoMode)videoMode;
- (void)updateVideoChannels:(NSArray *)videoChannels;

- (void)printMicrophonesList;
- (void)setMicrophone:(CSMicrophoneDevice*)microphone;

- (void)printSpeakersList;
- (void)setSpeaker:(CSSpeakerDevice*)speaker;

- (BOOL)startPlayingTone:(id<CSAudioFilePlayerListener>)audioFilePlayerListener toneToBePlayed: (CSAudioTone)tone playInLoop: (BOOL)loop;
- (BOOL)stopPlayingTone;
- (void)prepareAudioForCallsWithVideo:(BOOL)video;
- (void)configureAudioSession;

@end


