/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>
#import "ClientCredentialProvider.h"

@interface ConfigData : NSObject

/**
 * SIP Login status
 */
typedef NS_ENUM(NSInteger, SipLoginStatus) {
    SipLoginStatusLoggedOut,
    SipLoginStatusLoggingIn,
    SipLoginStatusLoggedIn
};

/**
 * Messaging Login status
 */
typedef NS_ENUM(NSInteger, MessagingLoginStatus) {
    MessagingLoginStatusLoggedOut,
    MessagingLoginStatusLoggingIn,
    MessagingLoginStatusLoggedIn
};

/**
 * ACS Login status
 */
typedef NS_ENUM(NSInteger, ACSLoginStatus) {
    ACSLoginStatusLoggedOut,
    ACSLoginStatusLoggedIn
};

@property (nonatomic, readwrite) NSString* sipUsername;
@property (nonatomic, readwrite) NSString* sipPassword;
@property (nonatomic, readwrite) NSString* sipProxyAddress;
@property (nonatomic, readwrite) int sipProxyPort;
@property (nonatomic, readwrite) NSString* sipTransport;
@property (nonatomic, readwrite) NSString* sipDomain;
@property (nonatomic, readwrite) BOOL callKitEnabled;

@property (nonatomic, readwrite) NSString* messagingUsername;
@property (nonatomic, readwrite) NSString* messagingPassword;
@property (nonatomic, readwrite) NSString* messagingServerAddress;
@property (nonatomic, readwrite) int messagingPort;
@property (nonatomic, readwrite) int messagingRefreshInterval;
@property (nonatomic, readwrite) BOOL messagingConnectionTypeSecure;

@property (nonatomic, readwrite) NSString* acsUsername;
@property (nonatomic, readwrite) NSString* acsPassword;
@property (nonatomic, readwrite) NSString* acsServerAddress;
@property (nonatomic, readwrite) int acsPort;
@property (nonatomic, readwrite) BOOL acsConnectionTypeSecure;
@property (nonatomic, readwrite) BOOL acsEnabled;

@property (nonatomic) BOOL isConfiguredForIPOffice;

@property (nonatomic, readwrite) SipLoginStatus sipLogin;
@property (nonatomic, readwrite) MessagingLoginStatus messagingLogin;
@property (nonatomic, readwrite) ACSLoginStatus acsLogin;

+ (instancetype) getInstance;

- (CSUserConfiguration *) userConfigurationFromConfigData: (ClientCredentialProvider *) clientCredentialProvider;
- (CSVoIPConfigurationAudio *) audioConfigurationFromConfigData;
- (CSVoIPConfigurationVideo *) videoConfigurationFromConfigData;

@end
