/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ConfigData.h"
#import "SDKManager.h"

@implementation ConfigData

ClientCredentialProvider *ldapCredentialProvider;
ClientCredentialProvider *acsCredentialProvider;
ClientCredentialProvider *sipCredentialProvider;
ClientCredentialProvider *ppmCredentialProvider;
ClientCredentialProvider *messagingCredentialProvider;

// Create single instance of ConfigData
+ (instancetype)getInstance {
    
    static dispatch_once_t once;
    static id sharedInstance;
    
    dispatch_once(&once, ^
                  {
                      sharedInstance = [self new];
                  });
    
    return sharedInstance;
}

- (instancetype) init {
    
    self = [super init];
    if (self) {
        
        self.sipLogin = SipLoginStatusLoggedOut;
        self.messagingLogin = MessagingLoginStatusLoggedOut;
        self.acsLogin = ACSLoginStatusLoggedOut;
        self.acsEnabled = NO;
        self.callKitEnabled = NO;
        
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        
        if (standardUserDefaults) {
            
            // Load configuration from NSUserDefaults
            self.sipUsername = [standardUserDefaults stringForKey:@"sipUsername"];
            self.sipPassword = [standardUserDefaults stringForKey:@"sipPassword"];
            self.sipProxyAddress = [standardUserDefaults stringForKey:@"sipProxyAddress"];
            self.sipDomain = [standardUserDefaults stringForKey:@"sipDomain"];
            self.sipProxyPort = (int)[standardUserDefaults integerForKey:@"sipProxyPort"];
            self.sipTransport = [standardUserDefaults stringForKey:@"sipTransport"];
            self.callKitEnabled = [standardUserDefaults boolForKey:@"callKitEnabled"];
            
            self.messagingUsername = [standardUserDefaults stringForKey:@"messagingUsername"];
            self.messagingPassword = [standardUserDefaults stringForKey:@"messagingPassword"];
            self.messagingServerAddress = [standardUserDefaults stringForKey:@"messagingServerAddress"];
            self.messagingPort = (int)[standardUserDefaults integerForKey:@"messagingPort"];
            self.messagingRefreshInterval = (int)[standardUserDefaults integerForKey:@"messagingRefreshInterval"];
            self.messagingConnectionTypeSecure = [standardUserDefaults boolForKey:@"messagingConnectionTypeSecure"];
            
            self.acsUsername = [standardUserDefaults stringForKey:@"acsUsername"];
            self.acsPassword = [standardUserDefaults stringForKey:@"acsPassword"];
            self.acsServerAddress = [standardUserDefaults stringForKey:@"acsServerAddress"];
            self.acsPort = (int)[standardUserDefaults integerForKey:@"acsPort"];
            self.acsConnectionTypeSecure = [standardUserDefaults boolForKey:@"acsConnectionTypeSecure"];
            
            // If NSUserDefaults does not contain application data then initialize with empty values
            if (self.sipUsername == nil) {
                self.sipUsername = @"";
            }
            if (self.sipPassword == nil) {
                self.sipPassword = @"";
            }
            if (self.sipProxyAddress == nil) {
                self.sipProxyAddress = @"";
            }
            if (self.sipDomain == nil) {
                self.sipDomain = @"";
            }
            if (self.sipProxyPort == 0) {
                self.sipProxyPort = 5061;
            }
            if (self.sipTransport == nil) {
                self.sipTransport = @"TLS";
            }
            if (self.messagingUsername == nil) {
                self.messagingUsername = @"";
            }
            if (self.messagingPassword == nil) {
                self.messagingPassword = @"";
            }
            if (self.messagingServerAddress == nil) {
                self.messagingServerAddress = @"";
            }
            if (self.messagingPort == 0) {
                self.messagingPort = 8443;
            }
            if (self.messagingRefreshInterval == 0) {
                self.messagingRefreshInterval = CSMessagingRefreshModePush;
            }
            if (self.messagingConnectionTypeSecure == NO) {
                self.messagingConnectionTypeSecure = YES;
            }
            if (self.acsUsername == nil) {
                self.acsUsername = @"";
            }
            if (self.acsPassword == nil) {
                self.acsPassword = @"";
            }
            if (self.acsServerAddress == nil) {
                self.acsServerAddress = @"";
            }
            if (self.acsPort == 0) {
                self.acsPort = 8443;
            }
            if (self.acsConnectionTypeSecure == NO) {
                self.acsConnectionTypeSecure = YES;
            }
        }
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - Configuration

////////////////////////////////////////////////////////////////////////////////

- (CSUserConfiguration *) userConfigurationFromConfigData: (ClientCredentialProvider *) clientCredentialProvider {
    //  Check whether configuration needs to be setup for IPOffice or Aura
    if (self.isConfiguredForIPOffice == YES) {
        //  Set up for IPOffice
        return [self setupUserConfigurationForIPOffice];
    }
    else {
        //  Set up for Aura
        return [self setupUserConfigurationForAura];
    }
}

- (CSUserConfiguration *)setupUserConfigurationForIPOffice {
    CSUserConfiguration *userConfiguration = [[CSUserConfiguration alloc] init];
    
    userConfiguration.IPOfficeConfiguration = [self getIPOfficeConfigurationFromConfigData];
    userConfiguration.dialingRulesConfiguration = [self getDialingRulesConfigurationFromConfigData];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *basePathsArray = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    
    NSURL *basePath = basePathsArray[0];
    NSURL *callLogFilePath = [basePath URLByAppendingPathComponent:[NSString stringWithFormat:@"CallLog-%@.xml", self.sipUsername]];
    
    userConfiguration.localCallLogFilePath = callLogFilePath;
    userConfiguration.localContactConfiguration = [self getLocalContactConfigurationFromConfigData];
    userConfiguration.SIPUserConfiguration = [self getSIPUserConfigurationFromConfigData];
    userConfiguration.videoUserConfiguration = [self getVideoUserConfigurationFromConfigData];
    userConfiguration.WCSConfiguration = [self getWCSConfigurationFromConfigData];
    
    return userConfiguration;
}

- (CSUserConfiguration *)setupUserConfigurationForAura {
    CSUserConfiguration *userConfiguration = [[CSUserConfiguration alloc] init];
    
    userConfiguration.ACSConfiguration = [self getACSConfigurationFromConfigData];
    userConfiguration.AMMConfiguration = [self getAMMConfigurationFromConfgData];
    userConfiguration.CESConfiguration = [self getCESConfigurationFromConfigData];
    userConfiguration.conferenceConfiguration = [self getConferenceConfigurationFromConfigData];
    userConfiguration.dialingRulesConfiguration = [self getDialingRulesConfigurationFromConfigData];
    userConfiguration.EC500Configuration = [self getEC500ConfigurationFromConfigData];
    userConfiguration.LDAPConfiguration = [self getLDAPConfigurationFromConfigData];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *basePathsArray = [fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    
    NSURL *basePath = basePathsArray[0];
    NSURL *callLogFilePath = [basePath URLByAppendingPathComponent:[NSString stringWithFormat:@"CallLog-%@.xml", self.sipUsername]];
    
    userConfiguration.localCallLogFilePath = callLogFilePath;
    userConfiguration.localContactConfiguration = [self getLocalContactConfigurationFromConfigData];
    userConfiguration.PPMConfiguration = [self getPPMConfigurationFromConfigData];
    userConfiguration.presenceConfiguration = [self getPresenceConfigurationFromConfigData];
    userConfiguration.SIPUserConfiguration = [self getSIPUserConfigurationFromConfigData];
    userConfiguration.videoUserConfiguration = [self getVideoUserConfigurationFromConfigData];
    userConfiguration.WCSConfiguration = [self getWCSConfigurationFromConfigData];
    
    return userConfiguration;
}

- (CSIPOfficeConfiguration *) getIPOfficeConfigurationFromConfigData {
    CSIPOfficeConfiguration *ipofficeConfiguration = [[CSIPOfficeConfiguration alloc] init];
    
    ipofficeConfiguration.enabled = true;
    ipofficeConfiguration.contactsEnabled = true;
    ipofficeConfiguration.presenceEnabled = true;
    ipofficeConfiguration.credentialProvider = [self getSIPUserConfigurationFromConfigData].credentialProvider;
    
    return ipofficeConfiguration;
}

- (CSACSConfiguration *) getACSConfigurationFromConfigData {
    
    CSACSConfiguration *ACSConfiguration = [[CSACSConfiguration alloc] init];
    
    if ((self.acsServerAddress.length != 0) &&
        (self.acsUsername.length !=0) &&
        (self.acsPassword.length != 0)) {
        
        ACSConfiguration.enabled = YES;
        self.acsEnabled = YES;
    } else {
        
        ACSConfiguration.enabled = NO;
    }
    
    acsCredentialProvider = [[ClientCredentialProvider alloc] initWithUserId:self.acsUsername password:self.acsPassword andDomain:nil];
    acsCredentialProvider.idInfo = @"ACS";
    
    ACSConfiguration.server = [CSServerInfo serverWithHostName: self.acsServerAddress
                                                          port: self.acsPort
                                                        secure: self.acsConnectionTypeSecure];
    
    ACSConfiguration.credentialProvider = acsCredentialProvider;
    
    return ACSConfiguration;
}

- (CSAMMConfiguration *) getAMMConfigurationFromConfgData {
    
    CSAMMConfiguration *AMMConfiguration = [[CSAMMConfiguration alloc] init];
    
    messagingCredentialProvider = [[ClientCredentialProvider alloc] initWithUserId:self.messagingUsername password:self.messagingPassword andDomain:nil];
    messagingCredentialProvider.idInfo = @"AMM";
    
    if ((self.messagingServerAddress.length != 0) &&
        (self.messagingUsername.length !=0) &&
        (self.messagingPassword.length != 0)) {
        
        AMMConfiguration.enabled = YES;
    } else {
        
        AMMConfiguration.enabled = NO;
    }
    
    AMMConfiguration.server = [CSServerInfo serverWithHostName:self.messagingServerAddress port:self.messagingPort secure:self.messagingConnectionTypeSecure];
    AMMConfiguration.credentialProvider = messagingCredentialProvider;
    AMMConfiguration.pollingIntervalInMinutes = self.messagingRefreshInterval;
    
    return AMMConfiguration;
}

- (CSCESConfiguration *) getCESConfigurationFromConfigData {
    
    CSCESConfiguration *CESConfiguration = [[CSCESConfiguration alloc] init];
    
    CESConfiguration.enabled = NO;
    
    return  CESConfiguration;
}

- (CSConferenceConfiguration *) getConferenceConfigurationFromConfigData {
    
    CSConferenceConfiguration *ConferenceConfiguration = [[CSConferenceConfiguration alloc] init];

    ConferenceConfiguration.conferenceFactoryURL = nil;
    ConferenceConfiguration.conferencePortalURL = nil;
    ConferenceConfiguration.moderatorCode = nil;
    ConferenceConfiguration.participantCode = nil;
    ConferenceConfiguration.moderatorURL = nil;
    ConferenceConfiguration.participantURL = nil;
    ConferenceConfiguration.virtualRoomID = nil;
    ConferenceConfiguration.uccpEnabled = NO;
    ConferenceConfiguration.uccpAdditionalFeaturesEnabled = NO;
    
    return ConferenceConfiguration;
}

- (CSDialingRulesConfiguration *) getDialingRulesConfigurationFromConfigData {
    
    CSDialingRulesConfiguration *DialingRulesConfiguration = [[CSDialingRulesConfiguration alloc] init];

    DialingRulesConfiguration.enabled = NO;
    
    return DialingRulesConfiguration;
}

- (CSEC500Configuration *) getEC500ConfigurationFromConfigData {
    
    CSEC500Configuration *EC500Configuration = [[CSEC500Configuration alloc] init];

    EC500Configuration.enabled = NO;
    
    return EC500Configuration;
}

- (CSLDAPConfiguration *) getLDAPConfigurationFromConfigData {
    
    CSLDAPConfiguration *LDAPConfiguration = [[CSLDAPConfiguration alloc] init];

    LDAPConfiguration.enabled = NO;
    
    return LDAPConfiguration;
}

- (CSLocalContactConfiguration *) getLocalContactConfigurationFromConfigData {
    
    CSLocalContactConfiguration *LocalContactConfiguration = [[CSLocalContactConfiguration alloc] init];
    
    LocalContactConfiguration.enabled = YES;
    
    return LocalContactConfiguration;
}

- (CSPPMConfiguration *) getPPMConfigurationFromConfigData {
    
    CSPPMConfiguration *PPMConfiguration = [[CSPPMConfiguration alloc] init];
    
    if ((self.sipUsername.length != 0) &&
        (self.sipPassword.length !=0) &&
        (self.sipDomain.length != 0)) {
        
        PPMConfiguration.enabled = YES;
    } else {
        
        PPMConfiguration.enabled = NO;
    }
    
    PPMConfiguration.contactsEnabled = YES;
    
    ppmCredentialProvider = [[ClientCredentialProvider alloc] initWithUserId:self.sipUsername password:self.sipPassword andDomain:self.sipDomain];
    ppmCredentialProvider.idInfo = @"PPM";
    
    PPMConfiguration.credentialProvider = ppmCredentialProvider;
    
    return PPMConfiguration;
}

- (CSPresenceConfiguration *) getPresenceConfigurationFromConfigData {
    
    CSPresenceConfiguration *PresenceConfiguration = [[CSPresenceConfiguration alloc] init];
    
    PresenceConfiguration.enabled = YES;
    
    return PresenceConfiguration;
}

- (CSSIPUserConfiguration *) getSIPUserConfigurationFromConfigData {
    
    CSSIPUserConfiguration *SIPUserConfiguration = [[CSSIPUserConfiguration alloc] init];
    
    if ((self.sipUsername.length != 0) &&
        (self.sipPassword.length !=0) &&
        (self.sipDomain.length != 0)) {
        
        SIPUserConfiguration.enabled = YES;
    } else {
        
        SIPUserConfiguration.enabled = NO;
    }
    
    SIPUserConfiguration.connectionPolicy = [self getConnectionPolicyFromConfigData];
    SIPUserConfiguration.userId = [self sipUsername];
    SIPUserConfiguration.domain = [self sipDomain];
    sipCredentialProvider = [[ClientCredentialProvider alloc] initWithUserId:self.sipUsername password:self.sipPassword andDomain:self.sipDomain];
    sipCredentialProvider.idInfo = @"SIP";
    
    SIPUserConfiguration.credentialProvider = sipCredentialProvider;
    
    NSString *platformVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
    
    NSLog(@"%s Avaya Client Services Version: %@", __PRETTY_FUNCTION__, [CSClient versionString]);
    
    NSDictionary *projectInfo = [[NSBundle mainBundle] infoDictionary];
    SIPUserConfiguration.displayName = [NSString stringWithFormat:@"%@ %@ %@", @"Communications Package Sample App", [projectInfo objectForKey:@"CFBundleSupportedPlatforms"][0], platformVersion];
    SIPUserConfiguration.language = @"en";
    SIPUserConfiguration.mobilityMode = CSSIPMobilityModeMobile;
    SIPUserConfiguration.alternateNetwork = @"mobile"; // Generally set to "mobile" for dual-mode clients.
    SIPUserConfiguration.alternateAddressOfRecord = nil; // For a dual-mode client, this specifies the user's cell number.
    SIPUserConfiguration.SRTCPEnabled = YES;
    SIPUserConfiguration.SIPClientConfiguration = [self getSIPClientConfigurationFromConfigData];
    SIPUserConfiguration.voipCallingPreference = CSMediaTransportAllTransports;

    return SIPUserConfiguration;
}

- (CSVideoUserConfiguration *) getVideoUserConfigurationFromConfigData {
    
    CSVideoUserConfiguration *VideoUserConfiguration = [[CSVideoUserConfiguration alloc] init];
    
    VideoUserConfiguration.enabledPreference = CSMediaTransportAllTransports;
    
    return VideoUserConfiguration;
}

- (CSWCSConfiguration *) getWCSConfigurationFromConfigData {
    
    CSWCSConfiguration *WCSConfiguration = [[CSWCSConfiguration alloc] init];
    WCSConfiguration.enabled = YES;
    
    return  WCSConfiguration;
}

- (CSVoIPConfigurationAudio *) audioConfigurationFromConfigData {
    
    CSVoIPConfigurationAudio *VoIPConfigurationAudio = [[CSVoIPConfigurationAudio alloc] init];
    
    // Audio configuration parameters
    VoIPConfigurationAudio.disableSilenceSup = NO;
    VoIPConfigurationAudio.dscpAudio = 0;
    VoIPConfigurationAudio.firstPingInterval = 2;
    VoIPConfigurationAudio.periodicPingInterval = 15;
    VoIPConfigurationAudio.minPortRange = 1024;
    VoIPConfigurationAudio.maxPortRange = 65535;
    VoIPConfigurationAudio.dtmfPayloadType = 120;
    VoIPConfigurationAudio.codecList = [NSArray arrayWithObjects:
                                        [NSNumber numberWithInteger:CSAudioCodecG711A],
                                        [NSNumber numberWithInteger:CSAudioCodecG711U],
                                        [NSNumber numberWithInteger:CSAudioCodecG722],
                                        [NSNumber numberWithInteger:CSAudioCodecG729],
                                        [NSNumber numberWithInteger:CSAudioCodecG726_32],
                                        [NSNumber numberWithInteger:CSAudioCodecIsac],
                                        nil];
    VoIPConfigurationAudio.voiceActivityDetectionMode = CSVoiceActivityDetectionModeDefault;
    VoIPConfigurationAudio.echoCancellationMode = CSEchoCancelationModeDefault;
    VoIPConfigurationAudio.echoCancellationMobileMode = CSEchoCancellationMobileModeDefault;
    VoIPConfigurationAudio.backgroundNoiseGenerationMode = CSBackgroundNoiseGenerationModeOn;
    VoIPConfigurationAudio.opusMode = CSOpusCodecProfileModeSuperWideBand;
    VoIPConfigurationAudio.transmitNoiseSuppressionMode = CSNoiseSuppressionModeDefault;
    VoIPConfigurationAudio.receiveNoiseSuppressionMode = CSNoiseSuppressionModeDefault;
    VoIPConfigurationAudio.transmitAutomaticGainControlMode = CSAutomaticGainControlModeDefault;
    VoIPConfigurationAudio.receiveAutomaticGainControlMode = CSAutomaticGainControlModeOff;
    VoIPConfigurationAudio.opusMode = CSOpusCodecProfileModeNarrowBand;
    VoIPConfigurationAudio.toneFilePath = [[NSBundle mainBundle] resourcePath];
	
    return VoIPConfigurationAudio;
}

- (CSVoIPConfigurationVideo *) videoConfigurationFromConfigData {
    
    CSVoIPConfigurationVideo *VoIPConfigurationVideo = [[CSVoIPConfigurationVideo alloc] init];
    
    // Video configuration parameters
    VoIPConfigurationVideo.enabled = YES;
    VoIPConfigurationVideo.cpuAdaptiveVideoEnabled = YES;
    VoIPConfigurationVideo.dscpVideo = 0;
    VoIPConfigurationVideo.firstVideoPingInterval = 2;
    VoIPConfigurationVideo.periodicVideoPingInterval = 15;
    VoIPConfigurationVideo.minPortRange = 5500;
    VoIPConfigurationVideo.maxPortRange = 64000;
    VoIPConfigurationVideo.bfcpMode = CSBFCPModeDisabled;
    VoIPConfigurationVideo.congestionControlAlgorithm = CSCongestionControlAlgorithmGoogle;
    VoIPConfigurationVideo.anyNetworkBandwidthLimitKbps = 1280;
    VoIPConfigurationVideo.cellularNetworkBandwidthLimitKbps = 512;
    VoIPConfigurationVideo.maxVideoResolution = CSMaxVideoResolutionAuto;
    
    return VoIPConfigurationVideo;
}

- (CSConnectionPolicy *) getConnectionPolicyFromConfigData {
    
    // Create SIP Proxy server group
    NSArray *serverList = [NSArray array];
    
    CSTransportType transportType = CSTransportTypeAutomatic;
    if ([[self sipTransport] compare: @"tls" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        
        transportType = CSTransportTypeTLS;
    } else if ([[self sipTransport] compare: @"tcp" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        
        transportType = CSTransportTypeTCP;
    } else if ([[self sipTransport] compare: @"udp" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        
        transportType = CSTransportTypeUDP;
    }
    
    CSSignalingServer *SignalingServer1 = [CSSignalingServer serverWithTransportType: transportType hostName: [self sipProxyAddress] port: (NSUInteger)[self sipProxyPort] failbackPolicy:CSFailbackPolicyAutomatic];
    
    serverList = [serverList arrayByAddingObject:SignalingServer1];
    
    CSRegistrationGroup *RegistrationGroup = [CSRegistrationGroup registrationGroupWithSignalingServers:serverList];
    
    NSArray *m_RegistrationGroups = [NSArray array];
    m_RegistrationGroups = [m_RegistrationGroups arrayByAddingObject:RegistrationGroup];
    
    CSSignalingServerGroup *SignalingServerGroup = [CSSignalingServerGroup signalingServerGroupWithRegistrationGroups:m_RegistrationGroups];
    
    CSConnectionPolicy *ConnectionPolicy = [CSConnectionPolicy connectionPolicyWithSignalingServerGroup:SignalingServerGroup];
    
    ConnectionPolicy.pingInterval = 30;
    ConnectionPolicy.pingTimeout = 0;
    ConnectionPolicy.keepAliveInterval = 30;
    ConnectionPolicy.keepAliveCount = 3;
    ConnectionPolicy.initialReconnectInterval = 60;
    
    return ConnectionPolicy;
}

- (CSSIPClientConfiguration *) getSIPClientConfigurationFromConfigData {
    
    CSSIPClientConfiguration *SIPClientConfiguration = [[CSSIPClientConfiguration alloc] init];
    
    // SIP Client configuration parameters
    /*SIPClientConfiguration.signalingDSCP = 24;
     SIPClientConfiguration.registrationTimeout = 3600;
     SIPClientConfiguration.subscriptionTimeout = 3600;
     SIPClientConfiguration.publishTimeout = 3600;
     SIPClientConfiguration.sessionRefreshTimeout = 1800;
     SIPClientConfiguration.maxForwardLimit = 70;
     SIPClientConfiguration.periodicRingbackTimeout = 60;
     SIPClientConfiguration.totalRingbackTimeout = 180;
     SIPClientConfiguration.waitTimeForCallCancel = 5;
     SIPClientConfiguration.transferCompletionTimeout = 185;
     SIPClientConfiguration.localVideoResponseTimeout = 15;
     SIPClientConfiguration.lineReservationTimeout = 30;
     SIPClientConfiguration.fastResponseTimeout = 5;
     SIPClientConfiguration.selectCodecBasedOnCallerPreferences = YES;
     SIPClientConfiguration.SIPSAndSRTPCouplingEnabled = YES;
     SIPClientConfiguration.reliableProvisionalResponsesEnabled = YES;*/
	
    return SIPClientConfiguration;
}

////////////////////////////////////////////////////////////////////////////////

@end
