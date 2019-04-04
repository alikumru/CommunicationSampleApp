/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ConfigData.h"
#import "SDKManager.h"

@implementation ConfigData

ClientCredentialProvider *unifiedPortalCredentialProvider;


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
        
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        
        if (standardUserDefaults) {
            
            // Load configuration from NSUserDefaults
            // Load configuration from NSUserDefaults
            self.conferenceUsername = [standardUserDefaults stringForKey:@"conferenceUsername"];
            self.conferencePassword = [standardUserDefaults stringForKey:@"conferencePassword"];
            self.conferenceURL = [standardUserDefaults stringForKey:@"conferenceURL"];
            self.displayName = [standardUserDefaults stringForKey:@"displayName"];
            
            if ([standardUserDefaults objectForKey:@"loginAsGuest"] == nil) {
                self.loginAsGuest = YES;
            } else {
                self.loginAsGuest = [standardUserDefaults boolForKey:@"loginAsGuest"];
            }

            // If NSUserDefaults does not contain application data then initialize with empty values
            if (self.conferenceUsername == nil) {
                self.conferenceUsername = @"";
            }
            if (self.conferencePassword == nil) {
                self.conferencePassword = @"";
            }
            if (self.conferenceURL == nil) {
                self.conferenceURL = @"";
            }
            if (self.displayName == nil) {
                self.displayName = @"";
            }
        }
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - Configuration

////////////////////////////////////////////////////////////////////////////////

- (CSUserConfiguration *) userConfigurationFromConfigData {
    
    CSUserConfiguration *userConfiguration = [[CSUserConfiguration alloc] init];
    
    userConfiguration.conferenceConfiguration = [self conferenceConfigurationFromConfigData];
    userConfiguration.HTTPUserConfiguration = [self httpUserConfiguration];
    userConfiguration.videoUserConfiguration = [self videoUserConfigurationFromConfigData];
    
    return userConfiguration;
}

- (CSConferenceConfiguration *) conferenceConfigurationFromConfigData {
    
    CSConferenceConfiguration *ConferenceConfiguration = [[CSConferenceConfiguration alloc] init];

    ConferenceConfiguration.conferenceFactoryURL = nil;
    ConferenceConfiguration.conferencePortalURL = nil;
    ConferenceConfiguration.moderatorCode = nil;
    ConferenceConfiguration.participantCode = nil;
    ConferenceConfiguration.moderatorURL = nil;
    ConferenceConfiguration.participantURL = nil;
    ConferenceConfiguration.virtualRoomID = nil;
    ConferenceConfiguration.uccpEnabled = YES;
    ConferenceConfiguration.uccpAdditionalFeaturesEnabled = YES;
    ConferenceConfiguration.enhancedConferencingEnabled = YES;
    
    return ConferenceConfiguration;
}

- (CSHTTPUserConfiguration *) httpUserConfiguration {
    CSHTTPUserConfiguration *httpUserConfiguration = [[CSHTTPUserConfiguration alloc] init];
    httpUserConfiguration.enabled = YES;
    
    return httpUserConfiguration;
}

- (CSVideoUserConfiguration *) videoUserConfigurationFromConfigData {
    
    CSVideoUserConfiguration *VideoUserConfiguration = [[CSVideoUserConfiguration alloc] init];
    
    VideoUserConfiguration.enabledPreference = CSMediaTransportAllTransports;
    
    return VideoUserConfiguration;
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

- (CSUnifiedPortalConfiguration *) unifiedPortalConfiguration {
    
    NSString *urlString = [self.conferenceURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
    
    // Get conference ID from URL
    self.conferenceID = nil;
    NSArray<NSURLQueryItem*> *queryItems = [urlComponents queryItems];
    for (NSURLQueryItem* item in queryItems) {
        if ([[item name] isEqualToString:@"ID"]) {
            self.conferenceID = [item value];
            break;
        }
    }
    
    urlComponents.query = @"";
    self.portalURL = [urlComponents URL];
    
    // Create Unified Portal configuration object
    CSUnifiedPortalConfiguration *unifiedPortalConfiguration = [[CSUnifiedPortalConfiguration alloc] init];
    
    // Specify Unified Portal URL (mandatory)
    unifiedPortalConfiguration.serverURL = self.portalURL;
    
    if (!self.loginAsGuest) {
        // Specify credential provider to sign in portal to join the meeting as signed in user.
        unifiedPortalCredentialProvider = [[ClientCredentialProvider alloc] initWithUserId: self.conferenceUsername
                                                                                  password: self.conferencePassword
                                                                                 andDomain: @""];
        unifiedPortalCredentialProvider.idInfo = @"UnifiedPortal";
    } else {
        unifiedPortalCredentialProvider = nil;
    }
    
    unifiedPortalConfiguration.credentialProvider = unifiedPortalCredentialProvider;
    
    return unifiedPortalConfiguration;
}

////////////////////////////////////////////////////////////////////////////////

- (void) saveConfiguration {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    if (standardUserDefaults) {
        [standardUserDefaults setObject:self.conferenceUsername forKey:@"conferenceUsername"];
        [standardUserDefaults setObject:self.conferencePassword forKey:@"conferencePassword"];
        [standardUserDefaults setObject:self.conferenceURL forKey:@"conferenceURL"];
        [standardUserDefaults setObject:self.displayName forKey:@"displayName"];
        [standardUserDefaults setBool:self.loginAsGuest forKey:@"loginAsGuest"];
        [standardUserDefaults synchronize];
    }
}

@end
