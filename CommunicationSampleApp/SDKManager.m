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
CSCallFeatureServiceDelegate,
CSCallLogServiceDelegate,
CSContactDelegate,
CSContactServiceDelegate,
CSDataRetrievalDelegate,
CSVideoInterfaceDelegate,
CSCollaborationDelegate,
CSCollaborationServiceDelegate,
CSContentSharingDelegate,
CXProviderDelegate>
{
    CSUserConfiguration *userConfig;
    ClientCredentialProvider *credentialProvider;
    CSMediaServicesInstance *mediaServices;
}

@property (nonatomic) NSUUID *callHoldingUUID;
@property (nonatomic, copy) void (^waitingForCallHeld)(void);

- (void)reportCallActivityToCallKit:(CSCall *)call held:(BOOL)held;

@end

@implementation SDKManager

@synthesize activeCall;
@synthesize mediaManager;

////////////////////////////////////////////////////////////////////////////////

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        self.users = [NSMutableArray array];
        self.calls = [NSMutableDictionary dictionary];
    }
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

- (CSCall *)callWithUUID:(NSUUID *)UUID {
    @synchronized(self.calls) {
        CSCall *call = self.calls[UUID];
        return call;
    }
}


////////////////////////////////////////////////////////////////////////////////

#pragma mark - Client setup

////////////////////////////////////////////////////////////////////////////////

- (void)setupClient {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    if (self.client) {
        
        // Client is already initialized, shutdown previous instance of client and create a new one
        for (CSUser *user in self.users) {
            
            [self removeUsersObject:user];
        }
        [self.client shutdown:YES];
        
        configuration.sipLogin = SipLoginStatusLoggedOut;
        configuration.acsLogin = ACSLoginStatusLoggedOut;
        configuration.messagingLogin = MessagingLoginStatusLoggedOut;
        configuration.acsEnabled = NO;
    }
    
    if ((configuration.sipLogin == SipLoginStatusLoggedOut && configuration.sipUsername.length == 0) &&
        (configuration.acsLogin == ACSLoginStatusLoggedOut && configuration.acsUsername.length == 0) &&
        (configuration.messagingLogin == MessagingLoginStatusLoggedOut && configuration.messagingUsername.length == 0)) {
        
        return;
    }
    
    self.callKitEnabled = configuration.callKitEnabled;
    
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
    if (self.callKitEnabled)
    {
        clientConfiguration.cellularCallDetectionEnabled = NO;
    }
    self.client = [[CSClient alloc] initWithConfiguration: clientConfiguration
                                                 delegate: self
                                            delegateQueue: dispatch_get_main_queue()];
    
    credentialProvider = [[ClientCredentialProvider alloc] initWithUserId:configuration.sipUsername password:configuration.sipPassword andDomain:configuration.sipDomain];
    
    CSUserConfiguration *userConfiguration = [configuration userConfigurationFromConfigData: credentialProvider];
    
    [self.client createUserWithConfiguration: userConfiguration
                           completionHandler: ^(CSUser *user, NSError *error) {
                               
                               if (user) {
                                   
                                   NSLog(@"%s User created successfully", __PRETTY_FUNCTION__);
                                   [self addUsersObject: user];
                                   // Send Notification to start user registration
                                   [[NSNotificationCenter defaultCenter] postNotificationName:kStartSIPLoginNotification object:nil];
                               }
                               
                               if (error) {
                                   
                                   NSLog(@"%s Error creating a user: %@@%@\nCode = %ld\n%@", __PRETTY_FUNCTION__,
                                         configuration.sipUsername, configuration.sipDomain,
                                         (long)error.code, error.localizedDescription);
                                   [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@" Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
                               }
                           }];
    
    mediaManager = [[MediaManager alloc] initWithClient:self.client];
    
    if (self.callKitEnabled)
    {
        self.endCallActions = [NSMutableArray arrayWithCapacity:3];
        [self callKitProvider];
        [self callKitController];
    }
}

- (BOOL)hasPendingCall {
    return self.waitingForActivation != nil;
}

+ (NSString*)generateUserAgentInstanceId {
    UIDevice *device = [UIDevice currentDevice];
    NSString *currentDeviceId = [[device identifierForVendor]UUIDString];
    return currentDeviceId;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - Add/Remove objects to dictionaries

////////////////////////////////////////////////////////////////////////////////

- (void)removeUsersObject:(CSUser *)object {
    
    object.registrationDelegate = nil;
    object.callService.delegate = nil;
    object.collaborationService.delegate = nil;
    object.callLogService.delegate = nil;
    object.callFeatureService.delegate = nil;
    object.messagingService.delegate = nil;
    self.messagingServiceManager = nil;
    [self.users removeObject: object];
}

- (void)addUsersObject:(CSUser *)object {
    
    [self.users addObject:object];
    
    object.registrationDelegate = self;
    object.callService.delegate = self;
    object.collaborationService.delegate = self;
    object.callLogService.delegate = self;
    object.callFeatureService.delegate = self;
    
    self.messagingServiceManager = [[MessagingServiceManager alloc] initWithUser:object];
    
    object.messagingService.delegate = self.messagingServiceManager;
}

- (void)addCallsObject:(CSCall *)object {
    if (self.callKitEnabled)
    {
        NSLog(@"%s addCallsObject - %@", __PRETTY_FUNCTION__,object.UUID);
        self.calls[object.UUID] = object;
    }
    else {
        self.calls[@(object.callId)] = object;
    }
    object.delegate = self;
}

- (void)removeCallsObject:(CSCall *)object {
    
    object.delegate = nil;
    [self.calls removeObjectForKey: @(object.callId)];
}

- (void)addContactObject:(CSContact *)object {
    
    if (![self.contacts containsObject:object]) {
        
        [self.contacts addObject:object];
        object.delegate = self;
    }
}


- (void)removeContactObject:(CSContact *)object {
    
    if (![self.contacts containsObject:object]) {
        
        object.delegate = nil;
        [self.contacts removeObject:object];
        
        // Stop watching presence if Enterprise contact
        if ([object hasContactSourceType:CSContactSourceTypeEnterprise]) {
            
            [object stopPresenceWithCompletionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                } else {
                    
                    NSLog(@"%s presence subscription removed successfully for contact: [%@]", __PRETTY_FUNCTION__, object);
                }
            }];
        }
    }
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSClientDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)clientDidShutdown:(CSClient *)client {
    NSLog(@"%s ", __PRETTY_FUNCTION__);
}

- (void)client:(CSClient *)client didCreateUser:(CSUser *)user {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
    if (self.callKitEnabled)
    {
        [self registerWithCallKitProvider];
    }
}

- (void)client:(CSClient *)client didRemoveUser:(CSUser *)user {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
}

- (void)registerWithCallKitProvider {
    self.callKitProvider = [[CXProvider alloc] initWithConfiguration:self.providerConfiguration];
    [self.callKitProvider setDelegate:self queue:nil];
    [self callController];
}

- (CXProviderConfiguration *)providerConfiguration {
    CXProviderConfiguration *providerConfiguration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Sample App"];
    providerConfiguration.maximumCallGroups = 5;
    providerConfiguration.maximumCallsPerCallGroup = 1;
    providerConfiguration.supportsVideo = YES;
    providerConfiguration.supportedHandleTypes = [NSSet setWithObject:@(CXHandleTypePhoneNumber)];
    
    return providerConfiguration;
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
    
    [ConfigData getInstance].sipLogin = SipLoginStatusLoggedIn;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
    
    // Add contacts watcher after successful registration
    if (!self.contactsRetrievalWatcher) {
        // Cancel all previous requests
        [self.contactsRetrievalWatcher cancel];
    }
    self.contactsRetrievalWatcher = [[CSDataRetrievalWatcher alloc] init];
    [self.contactsRetrievalWatcher addDelegate:self];
    
    [user.contactService retrieveContactsForSource:CSContactSourceTypeAll watcher:self.contactsRetrievalWatcher];
	

}

- (void)user:(CSUser *)user didFailToRegisterWithServer:(CSSignalingServer *)server error:(NSError *)error {
    NSLog(@"%s user(%@) server(%@)\nError code = %ld\n%@", __PRETTY_FUNCTION__,
          user.userId, server.hostName, (long)error.code, error.localizedDescription);
}

- (void)userDidRegisterWithAllServers:(CSUser *)user  {
    NSLog(@"%s user(%@)", __PRETTY_FUNCTION__, user.userId);
    [NotificationHelper displayToastToUser:[NSString stringWithFormat:@"Successfully Logged in: %@", [ConfigData getInstance].sipUsername]];
}

- (void)userDidFailToRegisterWithAllServers:(CSUser *)user willRetry:(BOOL)flag {
    NSLog(@"%s user(%@), willRetry = %@", __PRETTY_FUNCTION__, user.userId, flag? @"YES": @"NO" );
    
    if (!flag) {
        
        self.client = nil;
        [ConfigData getInstance].sipLogin = SipLoginStatusLoggedOut;
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
        [NotificationHelper displayMessageToUser: @"User failed to register with all servers" TAG: __PRETTY_FUNCTION__];
    } else {
        
        // Set state to 'Logging In'/ Connecting/ Acquiring service state
        [ConfigData getInstance].sipLogin = SipLoginStatusLoggingIn;
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
    
    [ConfigData getInstance].sipLogin = SipLoginStatusLoggedOut;
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
}

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
    [self reportCallActivityToCallKit:call held:YES];
}

- (void)callDidUnhold:(CSCall *)call {
    NSLog(@"%s call(%@)", __PRETTY_FUNCTION__, call);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
    [self reportCallActivityToCallKit:call held:NO];
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
    if (self.callKitEnabled)
    {
        for (CXEndCallAction *endCallAction in self.endCallActions) {
            if (endCallAction.UUID == call.UUID) {
    
                [self.endCallActions removeObject:endCallAction];
                break;
            }
        }
        
        [self reportCallEnd:call];
    }

    [self.mediaManager removeVideoFromCall:call];
    [self removeCallsObject: call];
    
    if (call.isMissed) {
        
        [[NSNotificationCenter defaultCenter]
        postNotificationName:kMissedCallNotification object:nil];
    } else {
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshActiveCallWindowNotification object:nil];
    }
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
    [self.mediaManager startPlayingTone:self.mediaManager toneToBePlayed:CSAudioToneIncomingCallInternal playInLoop:YES];
    
    if (call.isRemote)
    {
        NSLog(@"%s RemoteLineOwnerAddress:%@ RemoteLineID:%ld", __PRETTY_FUNCTION__, call.lineAppearanceOwnerAddress, (unsigned long)call.lineAppearanceId);
    }
    if (self.callKitEnabled)
    {
    
        CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:call.remoteNumber];
        
        CXCallUpdate *cxCallUpdate = [[CXCallUpdate alloc] init];
        cxCallUpdate.remoteHandle = callHandle;
        cxCallUpdate.supportsDTMF = call.sendDigitCapability.allowed;
        cxCallUpdate.supportsUngrouping = NO;
        cxCallUpdate.supportsGrouping = !call.isConference;
        cxCallUpdate.supportsDTMF = YES;
        cxCallUpdate.supportsHolding = YES;
        cxCallUpdate.supportsGrouping = YES;
        cxCallUpdate.localizedCallerName = call.remoteNumber;
        
        [mediaManager configureAudioSession];
        [self.callKitProvider reportNewIncomingCallWithUUID:call.UUID update:cxCallUpdate completion:^(NSError * _Nullable error) {
            if (!error)
            {
                NSLog(@"reportNewIncomingCall Call is reported successfully:%@", error);
            }
            else
            {
                [call denyWithCompletionHandler:nil];
                NSLog(@"reportNewIncomingCall error:%@", error);
            }
        }];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kIncomingCallNotification object: call];
    }
    [self addCallsObject: call];
}

- (CXCallController *)callController {
    if (!self.callKitController) {
        self.callKitController = [[CXCallController alloc] init];
    }
    return self.callKitController;
}

- (void)callService:(CSCallService *)callService didCreateCall:(CSCall *)call {
    NSLog(@"%s hasActiveCall:[%@] call(%@)", __PRETTY_FUNCTION__, callService.activeCall ? @"YES": @"NO", call);
    [self addCallsObject: call];
    
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

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSCallLogServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)callLogServiceDidLoad:(CSCallLogService *)callLogService {
    NSLog(@"%s Call log service did load", __PRETTY_FUNCTION__);
}

- (void)callLogService:(CSCallLogService *)callLogService didAddCallLogs:(NSArray *)addedCallLogItemsArray {
    NSLog(@"%s Call log service did add call logs", __PRETTY_FUNCTION__);
}

- (void)callLogService:(CSCallLogService *)callLogService didRemoveCallLogs:(NSArray *)removedCallLogItemsArray {
    NSLog(@"%s Call log service did remove call logs", __PRETTY_FUNCTION__);
}

- (void)callLogService:(CSCallLogService *)callLogService didUpdateCallLogs:(NSArray *)updatedCallLogItemsArray {
    NSLog(@"%s Call log service did update call logs", __PRETTY_FUNCTION__);
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSCallFeatureServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)callFeatureServiceDidBecomeAvailable:(CSCallFeatureService *)callFeatureService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureServiceDidBecomeUnavailable:(CSCallFeatureService *)callFeatureService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeFeatureCapability:(CSFeatureType)featureType
{
    NSLog(@"%s featureType: [%ld]", __PRETTY_FUNCTION__, (long)featureType);
}

- (void)callFeatureServiceFeatureStatusDidBecomeAvailable:(CSCallFeatureService *)callFeatureService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureServiceFeatureStatusDidBecomeUnavailable:(CSCallFeatureService *)callFeatureService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeFeatureStatus:(CSFeatureStatusParameters *)featureStatus
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureServiceDidChangeAvailableFeatures:(CSCallFeatureService *)callFeatureService
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeSendAllCallsStatus:(BOOL)enabled forExtension:(NSString *)extension
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeCallForwardingStatus:(BOOL)enabled forExtension:(NSString *)extension destination:(NSString *)destination
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeCallForwardingBusyNoAnswerStatus:(BOOL)enabled forExtension:(NSString *)extension destination:(NSString *)destination
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeEnhancedCallForwardingStatus:(CSEnhancedCallForwardingStatus *)featureStatus forExtension:(NSString *)extension
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeEC500Status:(BOOL)enabled
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeAutoCallbackStatus:(BOOL)enabled
{
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeBusyIndicator:(CSBusyIndicator *)busyIndicator
{
    NSLog(@"%s BusyIndicatorChanged for Destination : %@, busyState : %@", __PRETTY_FUNCTION__, [busyIndicator destinationExtension], busyIndicator.isBusy ? @"busy" : @"idle");
}

- (void)callFeatureService:(CSCallFeatureService *)callFeatureService didChangeCallPickupAlertStatus:(CSCallPickupAlertStatus *)callPickupAlertStatus {
    NSLog(@"%s Call pickup feature notification received", __PRETTY_FUNCTION__);
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

#pragma mark - CSContactDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)contactUpdated:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contactDidStartPresence:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contactDidStopPresence:(CSContact *)contact {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contact:(CSContact *)contact didUpdatePresence:(CSPresence *)presence {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactPresenceUpdatedNotification object:contact];
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSContactServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)contactServiceAvailable:(CSContactService *)contactService {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([ConfigData getInstance].acsEnabled) {
        
        [ConfigData getInstance].acsLogin = ACSLoginStatusLoggedIn;
        
        // Add contacts watcher after successful registration
        if (self.contactsRetrievalWatcher) {
            
            // Cancel all previous requests
            [self.contactsRetrievalWatcher cancel];
        }
        self.contactsRetrievalWatcher = [[CSDataRetrievalWatcher alloc] init];
        [self.contactsRetrievalWatcher addDelegate:self];
        
        [contactService retrieveContactsForSource:CSContactSourceTypeAll watcher:self.contactsRetrievalWatcher];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactServiceAvailabilityChangedNotification object:nil];
}

- (void)contactServiceUnavailable:(CSContactService *)contactService {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if ([ConfigData getInstance].acsEnabled) {
        
        [ConfigData getInstance].acsLogin = ACSLoginStatusLoggedOut;
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactServiceAvailabilityChangedNotification object:nil];
}

- (void)contactService:(CSContactService *)contactService providerStartupFailedWithError:(NSError *)error forSource:(CSContactSourceType)source {
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
}

- (void)contactService:(CSContactService *)contactService loadContactsCompleteForSource:(CSContactSourceType)source doneLoadingAllSources:(BOOL)done {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
}

- (void)contactService:(CSContactService *)contactService loadContactsFailedWithError:(NSError *)error forSource:(CSContactSourceType)source doneLoadingAllSources:(BOOL)done {
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
}

- (void)contactServiceDidReloadData:(CSContactService *)contactService {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
}

- (void)contactServiceDidChangeCapabilities:(CSContactService *)contactService {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactServiceAvailabilityChangedNotification object:nil];
}

- (void)contactService:(CSContactService *)contactService didAddContacts:(NSArray *)contacts {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    for (CSContact *contact in contacts) {
        
        [self addContactObject:contact];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
}

- (void)contactService:(CSContactService *)contactService didDeleteContacts:(NSArray *)contacts {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    for (CSContact *contact in contacts) {
        
        [self removeContactObject:contact];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
}

- (void)contactService:(CSContactService *)contactService providerForSourceType:(CSContactSourceType )sourceType didFailWithError:(NSError* )error {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    NSString *contactSource = nil;
    switch (sourceType) {
        case CSContactSourceTypeAll:
            contactSource = @"All";
            break;
        case CSContactSourceTypeLocal:
            contactSource = @"Local";
            break;
        case CSContactSourceTypeEnterprise:
            contactSource = @"Enterprise";
            break;
        default:
            contactSource = @"Unknown";
            break;
    }
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error in contact source [%@]. Error code [%ld] - %@", contactSource, (long)error.code, error.localizedDescription] TAG:__PRETTY_FUNCTION__];
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSDataRetrievalDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)dataRetrieval:(CSDataRetrieval *)dataRetrieval didUpdateProgress:(BOOL)determinate retrievedCount:(NSUInteger)retrievedCount totalCount:(NSUInteger)totalCount {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)dataRetrievalDidComplete:(CSDataRetrieval *)dataRetrieval {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)dataRetrieval:(CSDataRetrieval *)dataRetrieval didFailWithError:(NSError *)error {
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSDataRetrievalWatcherDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didUpdateProgress:(BOOL)determinate retrievedCount:(NSUInteger)retrievedCount totalCount:(NSUInteger)totalCount {
    NSLog(@"%s retrieved count: [%lu], total count: [%lu]", __PRETTY_FUNCTION__, (unsigned long)retrievedCount, (unsigned long)totalCount);
}

- (void)dataRetrievalWatcherDidComplete:(CSDataRetrievalWatcher *)dataRetrievalWatcher {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.contacts removeAllObjects];
    NSArray *contactsSnapshot = dataRetrievalWatcher.snapshot;
    self.contacts = [[NSMutableArray alloc]initWithArray:contactsSnapshot];
    for (CSContact *contact in self.contacts) {
        
        contact.delegate = self;
        
        // Start watching presence if Enterprise contact
        if ([contact hasContactSourceType:CSContactSourceTypeEnterprise]) {
            
            [contact startPresenceWithAccessControlBehavior:CSAccessControlBehaviorNone completionHandler:^(NSError *error) {
                
                if (error) {
                    
                    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                } else {
                    
                    NSLog(@"%s presence subscription successful for contact: [%@]", __PRETTY_FUNCTION__, contact);
                }
            }];
        }
    }
    
    // Sort contact list by firstName
    self.contacts = [[self.contacts sortedArrayUsingComparator:^NSComparisonResult(CSContact *contact1, CSContact *contact2){
        
        return [contact1.firstName.fieldValue compare:contact2.firstName.fieldValue options:NSCaseInsensitiveSearch];
        
    }] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactListUpdatedNotification object:nil];
}

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didFailWithError:(NSError *)error {
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
}

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didContentsChange:(CSDataCollectionChangeType)changeType changedItems:(NSArray *)changedItems {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    switch(changeType) {
        case CSDataCollectionChangeTypeAdded:
        {
            NSLog(@"%s %lu Contacts added.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                NSLog(@"%s contact: [%@]", __PRETTY_FUNCTION__, contact);
                contact.delegate = self;
                
                // Start watching presence if Enterprise contact
                if ([contact hasContactSourceType:CSContactSourceTypeEnterprise]) {
                    
                    [contact startPresenceWithAccessControlBehavior:CSAccessControlBehaviorNone completionHandler:^(NSError *error) {
                        
                        if (error) {
                            
                            NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                        } else {
                            
                            NSLog(@"%s presence subscription successful for contact: [%@]", __PRETTY_FUNCTION__, contact);
                        }
                    }];
                }
            }
            break;
        }
        case CSDataCollectionChangeTypeUpdated:
        {
            NSLog(@"%s %lu Contacts changed.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            break;
        }
        case CSDataCollectionChangeTypeDeleted:
        {
            NSLog(@"%s %lu Contacts deleted.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                NSLog(@"%s contact: [%@]", __PRETTY_FUNCTION__, contact);
                [self removeContactObject:contact];
            }
            break;
        }
        case CSDataCollectionChangeTypeCleared:
        {
            NSLog(@"%s %lu Contacts cleared.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
            for (CSContact* contact in changedItems) {
                
                NSLog(@"%s contact: [%@]", __PRETTY_FUNCTION__, contact);
                [self removeContactObject:contact];
            }
            break;
        }
    }
    // Sort contact list by firstName
    self.contacts = [[self.contacts sortedArrayUsingComparator:^NSComparisonResult(CSContact *contact1, CSContact *contact2){
        
        return [contact1.firstName.fieldValue compare:contact2.firstName.fieldValue options:NSCaseInsensitiveSearch];
        
    }] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kContactListUpdatedNotification object:nil];
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

#pragma mark - CSCollaborationDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)collaborationDidStart:(CSCollaboration *)collaboration {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kCollaborationStartedNotification object:collaboration];
}

- (void)collaborationDidEnd:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationServiceDidBecomeAvailable:(CSCollaboration *)collaboration {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationServiceDidBecomeUnavailable:(CSCollaboration *)collaboration {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationDidChangeCapabilities:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationDidEjectParticipant:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationDidChangePresenterPrivilege:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationDidChangeModeratorPrivilege:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)collaborationDidInitialize:(CSCollaboration *)collaboration {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSCollaborationServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)collaborationService:(CSCollaborationService *)collabService didCreateCollaboration:(CSCollaboration *)collab {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    collab.delegate = self;
    collab.contentSharing.delegate = self;
}

- (void)collaborationService:(CSCollaborationService *)collabService didRemoveCollaboration:(CSCollaboration *)collab {
    
    NSLog(@"%s", __PRETTY_FUNCTION__);
    collab.delegate = nil;
    collab.contentSharing.delegate = nil;
}

- (void)collaborationService:(CSCollaborationService *)collabService didFailToCreateCollaborationWithError:(NSError *)error {
    
    NSLog(@"%s Error [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
    [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Create Collaboration Failed. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
}

////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSContentSharingDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)contentSharing:(CSContentSharing *)content didStartByParticipant:(CSParticipant *)participant {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kContentSharingStartedByParticipant object:content];
}

- (void)contentSharingDidPause:(CSContentSharing *)content {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contentSharingDidResume:(CSContentSharing *)content {
    NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)contentSharingDidEnd:(CSContentSharing *)content {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [[NSNotificationCenter defaultCenter] postNotificationName:kCollaborationSessionEndedRemotely object:nil];
}

///////////////////////////////////////////////////////

- (CSCall *)callForId: (NSUInteger)callId {
    CSCall *call = self.calls[@(callId)];
    return call;
}

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


- (void)reportCallEnd:(CSCall *)call {
    if (!call.UUID) {
        return;
    }

    CXCallEndedReason reason = CXCallEndedReasonRemoteEnded;
    if (call.isFailed) {
        reason = CXCallEndedReasonFailed;
    } else if (!call.isAnswered) {
        reason = CXCallEndedReasonUnanswered;
    }
    [self.callKitProvider reportCallWithUUID:call.UUID endedAtDate:nil reason:reason];
}


- (void)holdOrUnHoldCall:(CSCall *)call {
    if (self.callKitEnabled) {
        if (call.unholdCapability.allowed) {
            NSLog(@"SDKManager:: Call[%ld],Call_UUID-%@: Un-Hold", (long)call.callId, call.UUID.UUIDString);
            [self reportCallActivityToCallKit:call held:NO];
        } else if (call.holdCapability.allowed) {
            NSLog(@"SDKManager:: Call[%ld],Call_UUID-%@: Hold", (long)call.callId, call.UUID.UUIDString);
            [self  reportCallActivityToCallKit:call held:YES];
        } else {
            // ignore if in a transition state
            NSLog(@"SDKManager:: Call[%ld]: Ignore Hold/Un-Hold", (long)call.callId);
            return;
        }
        [self callUpdated:call];
    }
    else {
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
}


- (void)reportCallActivityToCallKit:(CSCall *)call held:(BOOL)held {
    if (!call.UUID) {
        return;
    }
    
    if (self.callKitProvider)
    {
        CXSetHeldCallAction *cxSetHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:call.UUID onHold:held];
        NSLog(@"SDKManager::reportCallActivityToCallKit:: Call_UUID-%@",call.UUID.UUIDString);
        
        CXTransaction *cxTransaction = [[CXTransaction alloc] initWithAction:cxSetHeldCallAction];
        
        [self.callKitController requestTransaction:cxTransaction completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"SDKManager::reportCallActivityToCallKit:: transaction failed with error");
            } else {
                NSLog(@"SDKManager::reportCallActivityToCallKit:: transaction success");
            }
        }];
        [self callUpdated:call];
    }
}

- (void)callUpdated:(CSCall *)call {

    CXCallUpdate *cxCallUpdate = [[CXCallUpdate alloc] init];
    cxCallUpdate.remoteHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:call.remoteNumber];
    
    cxCallUpdate.hasVideo = NO;
    cxCallUpdate.supportsHolding = call.isHeld ? call.unholdCapability.allowed : call.holdCapability.allowed;
    cxCallUpdate.supportsDTMF = call.sendDigitCapability.allowed;
    cxCallUpdate.supportsUngrouping = NO;
    cxCallUpdate.supportsGrouping = !call.isConference;
    cxCallUpdate.localizedCallerName = call.callDisplayName;
    NSLog(@"SDKManager:callUpdated: Call[%ld]: remoteHandle:%@, localizedCallerName:%@, hasVideo:%@, supportsHolding:%@, supportsDTMF:%@, supportsUngrouping:%@, supportsGrouping:%@",
        (long)call.callId,
        cxCallUpdate.remoteHandle.value,
        cxCallUpdate.localizedCallerName,
        cxCallUpdate.hasVideo ? @"YES" : @"NO",
        cxCallUpdate.supportsHolding ? @"YES" : @"NO",
        cxCallUpdate.supportsDTMF ? @"YES" : @"NO",
        cxCallUpdate.supportsUngrouping ? @"YES" : @"NO",
        cxCallUpdate.supportsGrouping ? @"YES" : @"NO");
    [self.callKitProvider reportCallWithUUID:call.UUID updated:cxCallUpdate];
}

- (void)startCall:(CSCall *)call {
    if (self.callKitEnabled)
    {
        [self.callKitProvider reportOutgoingCallWithUUID:call.UUID connectedAtDate:nil];
    
        NSLog(@"SDKManager::startCall:Call[%ld] with UUID: %@", (long)call.callId, call.UUID.UUIDString);
        CXHandle *cxHandle = [[CXHandle alloc] initWithType:CXHandleTypePhoneNumber value:call.remoteAddress];
        CXStartCallAction *cxStartCallAction = [[CXStartCallAction alloc] initWithCallUUID:call.UUID handle:cxHandle];
        cxStartCallAction.video = NO;
   
        CXTransaction *cxTransaction = [[CXTransaction alloc] init];
        [cxTransaction addAction:cxStartCallAction];
   
        [self.callKitController requestTransaction:cxTransaction completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"SDKManager::startCall: transaction failed with error:%@", error);
            } else {
                NSLog(@"SDKManager::startCall: transaction success");
                CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
                callUpdate.remoteHandle = cxHandle;
                callUpdate.supportsDTMF = YES;
                callUpdate.supportsHolding = YES;
                callUpdate.supportsGrouping = YES;
                callUpdate.supportsUngrouping = YES;
                callUpdate.hasVideo = NO;
   
                [self.callKitProvider reportCallWithUUID:call.UUID updated:callUpdate];
            }
        }];
   
        [self.callKitProvider reportOutgoingCallWithUUID:call.UUID connectedAtDate:nil];
    }
    [call start];
}



- (void)endCall:(CSCall *)call {
    if (self.callKitEnabled) {
        [self endCallWithProvider:call];
        [self reportCallEnd:call];
    }
    [call end];
}

- (void)endCallWithProvider:(CSCall *)call {
    if (call.UUID) {

        CXEndCallAction *endCallAction = [[CXEndCallAction alloc]initWithCallUUID:call.UUID];
        [self.endCallActions addObject:endCallAction];
        CXTransaction *transaction = [[CXTransaction alloc]initWithAction:endCallAction];
        [self.callKitController requestTransaction:transaction completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"%s%s:", __PRETTY_FUNCTION__,"Failed");
            } else {
                NSLog(@"%s%s:", __PRETTY_FUNCTION__,"Succeeded");
            }
        }];
    } else {

        [call end];
    }
}


#pragma mark - CXProviderDelegate


- (void)providerDidBegin:(CXProvider *)provider {
    // this is getting called
}


- (void)providerDidReset:(CXProvider *)provider {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    // [self cleanupAllCalls];
}


- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    NSUUID *callUUID = action.callUUID;
    CSCall *call = [self callWithUUID:callUUID];
    NSLog(@"SDKManager::provider:performStartCallAction for Call[%ld] with UUID[%@]", (long)call.callId, call.UUID.UUIDString);
    
    [self.mediaManager prepareAudioForCallsWithVideo:NO];
    @synchronized (self) {
        [action fulfill];
        
        NSLog(@"SDKManager::provider:performStartCallAction: waiting for activation to start call");
        self.waitingForActivation = ^{
            if (call) {
                if (call.remote && (call.state == CSCallStateEstablished || call.state == CSCallStateHeld || call.state == CSCallStateHolding)) {
                    NSLog(@"SDKManager::provider:performStartCallAction: join from waitingForActivation");
                    [call joinWithStatusHandler:^(CSJoinStatus status, NSError *error) {
                        switch (status) {
                            case CSJoinStatusCompleted:
                                if (!error) {
                                    NSLog(@"SDKManager:: Call[%ld]: Join complete, isRemote: %@", (long)call.callId, (call.isRemote) ? @"YES" : @"NO");
                                }
                                break;
                            case CSJoinStatusStarted:
                                NSLog(@"SDKManager:: Call[%ld]: Join started", (long)call.callId);
                                break;
                            case CSJoinStatusWaitingForMediaResources:
                                NSLog(@"SDKManager:: Call[%ld]: Join waiting for media resources", (long)call.callId);
                                // Shouldn't happen.
                                break;
                            default:;
                        }
                    }];
                } else if (call.state == CSCallStateIdle) {
                    NSLog(@"SDKManager::provider:performStartCallAction: start from waitingForActivation");
                    [call start];
                } else if (call.state == CSCallStateAlerting || call.state == CSCallStateIgnored) {
                    NSLog(@"SDKManager::provider:performStartCallAction: accept from waitingForActivation");
                    [call accept];
                }
            }
        };
    }
}


- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    CSCall *call = [self callWithUUID:action.callUUID];
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (call) {
        [self.mediaManager prepareAudioForCallsWithVideo:NO];
        [action fulfill];
        
        //Find Main Story Board where all View controllers
        // are present
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        
        //Instantiate Navigation Controller of ActiveCallViewController
        UINavigationController *activeCallNavigationController = (UINavigationController*)[storyboard                                                                                                         instantiateViewControllerWithIdentifier: @"activeCallNavigationController"];
        ActiveCallViewController *activeController = (ActiveCallViewController *)[activeCallNavigationController topViewController];
        
        //Assign Current Call object to incoming Call
        activeController.currentCall = call;
        
        AppDelegate *delegate = (AppDelegate*) [[UIApplication sharedApplication] delegate];
        UIViewController *rootView = delegate.window.rootViewController;
        
        //Present controller on screen
        [rootView presentViewController:activeCallNavigationController animated:YES completion:nil];
        
        @synchronized (self) {

            self.waitingForActivation = ^{
                [call accept];
            };
        }
    } else {
        [action fail];
    }

}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    CSCall *call = [self callWithUUID:action.callUUID];
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (call && !call.remote) {

        [call end];
    
#define kMaxWaitForCallEnd 20 /* 2 seconds */
        NSUInteger count = 0;
        while (call.state != CSCallStateEnded && call.state != CSCallStateEnding) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
            beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            count++;
            if (count >= kMaxWaitForCallEnd) {
                break;
            }
        }
    }
#undef kMaxWaitForCallEnd
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.client audioSessionDidBecomeActive:YES];
    @synchronized (self) {
        if (self.waitingForActivation) {
            self.waitingForActivation();
            self.waitingForActivation = nil;
        }
    }
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    [self.client audioSessionDidBecomeActive:NO];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    CSCall *call = [self callWithUUID:action.callUUID];
    NSLog(@"SDKManager::provider:performSetHeldCallAction(%@) for Call[%ld] with UUID[%@]", action.isOnHold ? @"YES" : @"NO", (long)call.callId, call.UUID.UUIDString);
    if (!call) {
        NSLog(@"SDKManager::provider:performSetHeldCallAction: call not found");
        [action fail];
        return;
    }
    if (action.isOnHold) {
        if (call.isHeld) {
            NSLog(@"SDKManager::provider:performSetHeldCallAction: Call[%ld] already held", (long)call.callId);
            [action fulfill];
            return;
        }

        [call holdWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"SDKManager::provider:Hold for Call[%ld] with UUID[%@] failed. Error - %@", (long)call.callId, call.UUID.UUIDString, error.description);
                [action fail];
                @synchronized (self) {
                    if (call.UUID && [call.UUID isEqual:self.callHoldingUUID]) {
                        self.callHoldingUUID = nil;
                        self.waitingForCallHeld = nil;
                    }
                }
            } else {
                NSLog(@"SDKManager::provider:performSetHeldCallAction:Hold succeeded for Call[%ld] with UUID[%@]", (long)call.callId, call.UUID.UUIDString);
                [action fulfill];
                @synchronized (self) {
                    if (call.UUID && [call.UUID isEqual:self.callHoldingUUID]) {
                        self.callHoldingUUID = nil;
                        if (self.waitingForCallHeld) {
                            self.waitingForCallHeld();
                            self.waitingForCallHeld = nil;
                        }
                    }
               }
            }
        }];
    } else {
        if (!call.isHeld) {
            NSLog(@"SDKManager::provider:performSetHeldCallAction: Call[%ld] already unheld", (long)call.callId);
            [action fulfill];
            return;
        }
        [self.mediaManager prepareAudioForCallsWithVideo:NO];
        [call unholdWithCompletionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"SDKManager:: Call[%ld]: Failed to unhold the call. Error %@", (long)call.callId, error);
                [action fail];
            } else {
                NSLog(@"SDKManager::provider:performSetHeldCallAction: Call[%ld] unhold succeeded", (long)call.callId);
                [action fulfill];
            }
        }];
    }
}

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {
    NSLog(@"SDKManager::provider:performPlayDTMFCallAction: %@", action.digits);
    CSCall *call = [self callWithUUID:action.callUUID];
    if (!call) {
        [action fail];
        return;
    }
    if (call.sendDigitCapability.allowed) {
        NSRange range = NSMakeRange(0,1);
        for (;range.location < action.digits.length; range.location++) {
            NSString *digit = [action.digits substringWithRange:range];
            if ([digit isEqualToString:@"0"]) {
                [call sendDigit:CSDTMFToneZero];
            } else if ([digit isEqualToString:@"1"]) {
                [call sendDigit:CSDTMFToneOne];
            } else if ([digit isEqualToString:@"2"]) {
                [call sendDigit:CSDTMFToneTwo];
            } else if ([digit isEqualToString:@"3"]) {
                [call sendDigit:CSDTMFToneThree];
            } else if ([digit isEqualToString:@"4"]) {
                [call sendDigit:CSDTMFToneFour];
            } else if ([digit isEqualToString:@"5"]) {
                [call sendDigit:CSDTMFToneFive];
            } else if ([digit isEqualToString:@"6"]) {
                [call sendDigit:CSDTMFToneSix];
            } else if ([digit isEqualToString:@"7"]) {
                [call sendDigit:CSDTMFToneSeven];
            } else if ([digit isEqualToString:@"8"]) {
                [call sendDigit:CSDTMFToneEight];
            } else if ([digit isEqualToString:@"9"]) {
                [call sendDigit:CSDTMFToneNine];
            } else if ([digit isEqualToString:@"*"]) {
                [call sendDigit:CSDTMFToneStar];
            } else if ([digit isEqualToString:@"#"]) {
                [call sendDigit:CSDTMFTonePound];
            }
        }
        [action fulfill];
    } else {
        [action fail];
    }
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    NSLog(@"SDKManager::provider:performSetMutedCallAction:");
    CSCall *call = [self callWithUUID:action.callUUID];
    if (!call) {
        [action fail];
        return;
    }
    if (call.audioMuted != action.isMuted) {
        //[self muteOrUnMuteCall:call];
    }
    [action fulfill];
}


- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction {
    int i = 0;
    for (CXAction *action in transaction.actions) {
        if ([action isKindOfClass:CXSetHeldCallAction.class]) {
            CSCall *callToHold = [self callWithUUID:((CXSetHeldCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXSetHeldCallAction, Hold?%d, call-%@", i, ((CXSetHeldCallAction *)action).isOnHold, callToHold.description);
        } else if ([action isKindOfClass:CXAnswerCallAction.class]) {
            CSCall *callToAnswer = [self callWithUUID:((CXAnswerCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXAnswerCallAction, call-%@", i, callToAnswer.description);
        } else if ([action isKindOfClass:CXEndCallAction.class]) {
            CSCall *callToEnd = [self callWithUUID:((CXEndCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXEndCallAction, call-%@", i, callToEnd.description);
        } else if ([action isKindOfClass:CXStartCallAction.class]) {
            CSCall *callToStart = [self callWithUUID:((CXStartCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXStartCallAction, call-%@", i, callToStart.description);
        } else if ([action isKindOfClass:CXPlayDTMFCallAction.class]) {
            CSCall *call = [self callWithUUID:((CXPlayDTMFCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXPlayDTMFCallAction, call-%@", i, call.description);
        } else if ([action isKindOfClass:CXSetMutedCallAction.class]) {
            CSCall *call = [self callWithUUID:((CXSetMutedCallAction *)action).callUUID];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXSetMutedCallAction, call-%@", i, call.description);
        } else if ([action isKindOfClass:CXSetGroupCallAction.class]) {
            CSCall *call = [self callWithUUID:((CXSetGroupCallAction *)action).callUUID];
            CSCall *callToGroupWith = [self callWithUUID:((CXSetGroupCallAction *)action).callUUIDToGroupWith];
            NSLog(@"SDKManager::provider:executeTransaction:action[%d]=CXSetGroupCallAction, call-%@, callToGroupWith-%@", i, call.description, callToGroupWith.description);
        }
        i++;
    }
    return NO;
}

@end


