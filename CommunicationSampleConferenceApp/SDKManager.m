/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "SDKManager.h"
#import <AvayaClientServices/AvayaClientServices.h>
#import "ClientCredentialProvider.h"
#import "ConfigData.h"
#import "NotificationHelper.h"
#import "CSCall+Additions.h"
#import "ActiveCallViewController.h"
#import "AppDelegate.h"


@interface SDKManager()
<CSClientDelegate,
CSUserRegistrationDelegate,
CSCallDelegate,
CSCallServiceDelegate,
CSConferenceDelegate,
CSVideoInterfaceDelegate>
{
    CSUserConfiguration *userConfig;
    ClientCredentialProvider *credentialProvider;
    CSMediaServicesInstance *mediaServices;
}

@property (nonatomic) NSUUID *callHoldingUUID;
@property (nonatomic, copy) void (^waitingForCallHeld)(void);

@end

@implementation SDKManager

@synthesize activeCall;
@synthesize mediaManager;

////////////////////////////////////////////////////////////////////////////////

- (instancetype)init {
    
    self = [super init];

    return self;
}

////////////////////////////////////////////////////////////////////////////////

+ (instancetype)getInstance {
    
    static dispatch_once_t onceToken;
    static SDKManager *instance = nil;
    dispatch_once(&onceToken, ^{
        instance = [SDKManager new];
    });
    return instance;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - Client setup

////////////////////////////////////////////////////////////////////////////////

- (void)setupClient {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    if (self.client) {
        
        // Client is already initialized, shutdown previous instance of client and create a new one
        if (self.user) {
            
            self.user.registrationDelegate = nil;
            self.user.callService.delegate = nil;
        }
        [self.client shutdown:YES];
    }

    [CSClient setLogLevel: CSLogLevelDebug];
    
	NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *basePathsArray = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    
    NSString *product_dataDirectory = [basePathsArray[0] absoluteString];
    
    //Client configuration
	CSClientConfiguration *clientConfiguration = [[CSClientConfiguration alloc] initWithDataDirectory:product_dataDirectory];

    
    // A unique instance id of the user agent defined in RFC 5626.
    // For the real applications please generate unique value once (e.g. UUID [RFC4122]) and
    // then save this in persistent storage for all future use.
    clientConfiguration.userAgentInstanceId = [SDKManager generateUserAgentInstanceId];
    
    CSSecurityPolicyConfiguration *securityPolicyConfig = [[CSSecurityPolicyConfiguration alloc] init];
    
    securityPolicyConfig.continueOnTLSServerIdentityFailure = YES;
    
    securityPolicyConfig.revocationCheckPolicy = CSSecurityPolicyBestEffort;
    
    
    
    clientConfiguration.securityPolicyConfiguration = securityPolicyConfig;
    
    clientConfiguration.mediaConfiguration.audioConfiguration = [configuration audioConfigurationFromConfigData];
    clientConfiguration.mediaConfiguration.videoConfiguration = [configuration videoConfigurationFromConfigData];

    self.client = [[CSClient alloc] initWithConfiguration: clientConfiguration
                                                 delegate: self
                                            delegateQueue: dispatch_get_main_queue()];
    
    CSUserConfiguration *userConfiguration = [configuration userConfigurationFromConfigData];
    
    [self.client createUserWithConfiguration: userConfiguration
                           completionHandler: ^(CSUser *user, NSError *error) {
                               
                               if (user) {
                                   
                                   NSLog(@"%s User created successfully", __PRETTY_FUNCTION__);
                                   user.registrationDelegate = self;
                                   user.callService.delegate = self;
                                   [user start];
                                   self.user = user;
                               }
                               
                               if (error) {
                                   
                                   NSLog(@"%s Error creating a user: \nCode = %ld\n%@", __PRETTY_FUNCTION__,
                                         (long)error.code, error.localizedDescription);
                                   [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                               }
                           }];
    
    mediaManager = [[MediaManager alloc] initWithClient:self.client];
    
}

+ (NSString*)generateUserAgentInstanceId {
    UIDevice *device = [UIDevice currentDevice];
    NSString *currentDeviceId = [[device identifierForVendor]UUIDString];
    return currentDeviceId;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSClientDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)clientDidShutdown:(CSClient *)client {
    NSLog(@"%s ", __PRETTY_FUNCTION__);
}

- (void)client:(CSClient *)client didCreateUser:(CSUser *)user {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
}

- (void)client:(CSClient *)client didRemoveUser:(CSUser *)user {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSUserRegistrationDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)user:(CSUser *)user didStartRegistrationWithServer:(CSSignalingServer *)server {
    NSLog(@"%s user(%@) server(%@)", __PRETTY_FUNCTION__,
          user.userId, server.hostName);
}

- (void)user:(CSUser *)user didRegisterWithServer:(CSSignalingServer *)server {
    
    NSLog(@"%s user(%@) server(%@)", __PRETTY_FUNCTION__,
          user.userId, server.hostName);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
    
}

- (void)user:(CSUser *)user didFailToRegisterWithServer:(CSSignalingServer *)server error:(NSError *)error {
    NSLog(@"%s user(%@) server(%@)\nError code = %ld\n%@", __PRETTY_FUNCTION__,
          user.userId, server.hostName, (long)error.code, error.localizedDescription);
}

- (void)userDidRegisterWithAllServers:(CSUser *)user  {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
    [[NSNotificationCenter defaultCenter] postNotificationName:kUserDidRegisterNotification object:nil];
    [NotificationHelper displayToastToUser:[NSString stringWithFormat:@"Successfully Logged in"]];
}

- (void)userDidFailToRegisterWithAllServers:(CSUser *)user willRetry:(BOOL)flag {
    NSLog(@"%s user(%@), willRetry = %@", __PRETTY_FUNCTION__, user.userId, flag? @"YES": @"NO" );
    
    if (!flag) {
        
        self.client = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kUserDidFailToRegisterNotification object:nil];
        [NotificationHelper displayMessageToUser: @"User failed to register with all servers" TAG: __PRETTY_FUNCTION__];
    } else {
        
        [NotificationHelper displayMessageToUser: @"User failed to register with all servers, retrying..." TAG: __PRETTY_FUNCTION__];
    }
}

- (void)user:(CSUser *)user didStartUnregistrationWithServer:(CSSignalingServer *)server {
    NSLog(@"%s user(%@) server(%@)", __PRETTY_FUNCTION__,
          user.userId, server.hostName);
}

- (void)user:(CSUser *)user didUnregisterWithServer:(CSSignalingServer *)server {
    NSLog(@"%s user(%@) server(%@)", __PRETTY_FUNCTION__,
          user.userId, server.hostName);
}

- (void)user:(CSUser *)user didFailToUnregisterWithServer:(CSSignalingServer *)server error:(NSError *)error  {
    NSLog(@"%s user(%@) server(%@)\nError code = %ld\n%@", __PRETTY_FUNCTION__,
          user.userId, server.hostName, (long)error.code, error.localizedDescription);
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
}

- (void)userDidCompleteUnregistrationWithAllServers:(CSUser *)user  {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
}

- (void)user:(CSUser *)user didReceiveRegistrationResponsePayload:(NSArray *)payloadParts fromServer:(CSSignalingServer *)server {
    NSLog(@"%s user(%@) server(%@)", __PRETTY_FUNCTION__,
          user.userId, server.hostName);}


////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSCallDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)callDidStart:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidBeginRemoteAlerting:(CSCall *)call withEarlyMedia:(BOOL)hasEarlyMedia {
    NSLog(@"%s call(%@) %@", __PRETTY_FUNCTION__, call, hasEarlyMedia?@"hasEarlyMedia":@"noEarlyMedia");
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidEstablish:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [self.mediaManager stopPlayingTone];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidHold:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidUnhold:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidRemoteHold:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidRemoteUnhold:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidJoin:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callWasIgnored:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    
    [self.mediaManager stopPlayingTone];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidDeny:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [self.mediaManager startPlayingTone:self.mediaManager toneToBePlayed:CSAudioToneReorder playInLoop:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidEnd:(CSCall *)call reason:(CSCallEndReason)reason {
    NSLog(@"%s call(%@) ended with reason: %@", __PRETTY_FUNCTION__, call, (reason == CSCallEndReasonEndedLocally) ? @"CSCallEndReasonEndedLocally" : (reason == CSCallEndReasonCallDisconnected) ? @"CSCallEndReasonCallDisconnected" : @"CSCallEndReasonDisconnectedByConferenceModerator" );
    
    [self.mediaManager stopPlayingTone];

    if (call.isConference) {
        
        call.conference.delegate = nil;
    }

    [self.mediaManager removeVideoFromCall:call];
    call.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didFailWithError:(NSError *)error {
    NSLog(@"%s call(%@)\nCode=%ld\n%@", __PRETTY_FUNCTION__, call, (long)error.code, error.localizedDescription);
    [call end];
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Call Failed, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG:__PRETTY_FUNCTION__];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didMuteAudio:(BOOL)muted {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didUpdateVideoChannels:(NSArray *)videoChannels {
    NSLog(@"%s call(%@) %@", __PRETTY_FUNCTION__, call, videoChannels);
    [self.mediaManager updateVideoChannels:videoChannels];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didRemoteRemoveVideoChannel:(CSVideoChannel *)videoChannel {
    NSLog(@"%s call(%@) channel(%@)", __PRETTY_FUNCTION__, call, videoChannel);
    [mediaManager removeVideoFromCall:call];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidReceiveVideoAddRequest:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [mediaManager acceptVideoForCall:call withVideoMode:CSVideoModeSendReceive];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didAcceptVideoAddRequest:(CSVideoChannel *)videoChannel {
    NSLog(@"%s call(%@) channel(%@)", __PRETTY_FUNCTION__, call, videoChannel);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidDenyVideoAddRequest:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidTimeoutVideoAddRequest:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didChangeRemoteAddress:(NSString *)remoteAddress displayName:(NSString *)displayName {
    NSLog(@"%s call(%@) remoteAddress=%@  displayName=%@", __PRETTY_FUNCTION__, call, remoteAddress, displayName);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didChangeConferenceStatus:(BOOL)isConference {
    call.conference.delegate = self;
    NSLog(@"%s call(%@) to %@", __PRETTY_FUNCTION__, call, isConference?@"Conference":@"PeerToPeer");
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callServiceDidBecomeAvailable:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callServiceDidBecomeUnavailable:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidChangeCapabilities:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidRedirect:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidQueue:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callParticipantMatchedContactsChanged:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callDidRemoteControlAnswer:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didSilenceSpeaker:(BOOL)silenced{
    NSLog(@"%s call %@", __PRETTY_FUNCTION__, silenced?@"silenced":@"not silenced");
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)call:(CSCall *)call didChangeAllowedVideoDirection:(CSAllowedVideoDirection)videoDirection {
    NSLog(@"%s call new allowed video direction - %@", __PRETTY_FUNCTION__, [self stringForAllowedVideoDirection: videoDirection]);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSCallServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)callService:(CSCallService *)callService didReceiveIncomingCall:(CSCall *)call {
    NSLog(@"%s %@ call(%@)", __PRETTY_FUNCTION__, callService.activeCall, call);
}

- (void)callService:(CSCallService *)callService didCreateCall:(CSCall *)call {
    NSLog(@"%s hasActiveCall:[%@] call(%@)", __PRETTY_FUNCTION__, callService.activeCall ? @"YES": @"NO", call);
    call.delegate = self;
    
    // Play ringback tone only when call is not answered
    if (!callService.activeCall)
    {
        [self.mediaManager startPlayingTone:self.mediaManager toneToBePlayed:CSAudioToneRingback playInLoop:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callService:(CSCallService *)callService didReceiveNotificationOfUndeliveredCall:(CSCall *)call {
    NSLog(@"%s hasActiveCall:[%@] call(%@)", __PRETTY_FUNCTION__, callService.activeCall ? @"YES": @"NO", call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callService:(CSCallService *)callService didRemoveCall:(CSCall *)call {
    NSLog(@"%s hasActiveCall:[%@] call(%@)", __PRETTY_FUNCTION__, callService.activeCall ? @"YES": @"NO", call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callServiceDidChangeCapabilities:(CSCallService *)callService {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, callService);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)callService:(CSCallService *)callService didChangeActiveCall:(CSCall *)call {
    
    [mediaManager stopPlayingTone];
    activeCall = callService.activeCall;
    if (call)
    {
        NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    }
    else
    {
        NSLog(@"%s call(nil)", __PRETTY_FUNCTION__);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
    //NSAssert(call == activeCall, @"active call from api and callback should be same,");
}

- (void)callService:(CSCallService *)callService didReceiveNotificationOfUndeliveredIncomingCall:(CSCall *)call {
    NSLog(@"%s call: [%@]", __PRETTY_FUNCTION__, call);
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSConferenceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)conferenceWaitingToStart:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceDidStart:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceCapabilitiesDidChange:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)conference:(CSConference *)conference didChangeSubject:(NSString *)subject {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeBrandName:(NSString *)brandName {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeLockStatus:(BOOL)locked {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeLectureModeStatus:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeEntryExitToneStatus:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeContinuationStatus:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeRecordingStatus:(CSConferenceRecordingStatus)status {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeEncryptionStatus:(CSConferenceEncryptionStatus)status {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeStreamingStatus:(CSConferenceStreamingStatus) status {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeMeetingEndTime:(NSDate *)meetingEndTime {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeVideoStatus:(BOOL)allowed {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeVideoSelfSeeStatus:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeDisplayParticipantNameOnVideo:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeAlwaysDisplayActiveSpeakerVideo:(BOOL)active {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeActiveSpeakerVideoPosition:(int)position {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeVideoLayout:(CSVideoLayout)layout {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didChangeSupportedVideoLayouts:(NSArray *)layouts {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceHandRaised:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceHandLowered:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference didRequirePasscode:(BOOL)permissionToEnterLockedConferenceRequired {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceDidRequirePermissionToEnter:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceServiceDidBecomeAvailable:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conferenceServiceDidBecomeUnavailable:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference participantsDidChange:(CSDataCollectionChangeType)changeType changedParticipants:(NSArray *)changedParticipants {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // Publish notification to update active call screen on participant list change
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
}

- (void)conferenceRecordingDidFail:(CSConference *)conference {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)conference:(CSConference *)conference serviceDidBecomeUnavailable:(NSError *)error {
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
}

- (void)conference:(CSConference *)conference didChangeEventConferenceStatus:(BOOL)eventConferenceStatus {
    NSLog(@"%s is event conference: %@", __PRETTY_FUNCTION__, eventConferenceStatus ? @"true" : @"false");
}


////////////////////////////////////////////////

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

////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

+ (NSString *)applicationVersion {
    
    // Product version is extacted from SDK version for sample application
    // If, SDK version: x.x (yyy.y.y Build zzz)
    // Then, Application version: yyy.y.y
    return [[[CSClient versionString] componentsSeparatedByString:@" "][1] stringByReplacingOccurrencesOfString:@"(" withString:@""];
}

+ (NSString *)applicationBuildDate {
    
    NSDictionary *projectInfo = [[NSBundle mainBundle] infoDictionary];
    return [projectInfo objectForKey:@"ApplicationBuildDate"];
}

+ (NSString *)applicationBuildNumber {
    
    NSDictionary *projectInfo = [[NSBundle mainBundle] infoDictionary];
    return [projectInfo objectForKey:@"CFBundleVersion"];
}

- (NSString *)stringForAllowedVideoDirection:(CSAllowedVideoDirection)allowedVideoDirection {
    switch (allowedVideoDirection)
    {
        case CSAllowedVideoDirectionNone:
            return @"None";
            
        case CSAllowedVideoDirectionSendOnly:
            return @"SendOnly";
            
        case CSAllowedVideoDirectionReceiveOnly:
            return @"ReceiveOnly";
            
        case CSAllowedVideoDirectionSendReceive:
            return @"SendReceive";
    }
    
    return @"None";
}

- (void)holdOrUnHoldCall:(CSCall *)call {
    if (call.unholdCapability.allowed) {
        [call unholdWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"SDKManager:: Call[%ld]: Failed to unhold the call. Error %@", (long)call.callId, error);
            } else {
                NSLog(@"SDKManager::provider:performSetHeldCallAction: Call[%ld] unhold succeeded", (long)call.callId);
            }
        }];
    }
    else if (call.holdCapability.allowed) {
        [call holdWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"SDKManager::provider:Hold for Call[%ld] with UUID[%@] failed. Error - %@", (long)call.callId, call.UUID.UUIDString, error.description);
            } else {
                NSLog(@"SDKManager::provider:performSetHeldCallAction:Hold succeeded for Call[%ld] with UUID[%@]", (long)call.callId, call.UUID.UUIDString);
            }
        }];
    }
}

- (void)endCall:(CSCall *)call {
    [call end];
}

@end


