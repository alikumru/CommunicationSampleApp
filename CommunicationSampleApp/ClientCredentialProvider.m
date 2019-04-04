/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ClientCredentialProvider.h"
#import "SDKManager.h"
#import "NotificationHelper.h"
#import <CommonCrypto/CommonDigest.h>

@implementation ClientCredentialProvider {
    
    NSString *_userId;
    NSString *_password;
    NSString *_domain;
    NSString *_ha1String;
}

- (instancetype)initWithUserId:(NSString *)userId
                      password:(NSString *)password
                        domain:(NSString *)domain
                  andHa1String:(NSString *)ha1String {
    
    self = [super init];
    
    if (self != nil) {
        
        _userId = userId;
        _password = password;
        _domain = domain;
        _ha1String = ha1String;
        self.idInfo = @"SIP";
    }
    return self;
}

- (instancetype)initWithUserId:(NSString *)userId
                      password:(NSString *)password
                     andDomain:(NSString *)domain {
    
    self = [super init];
    
    if (self != nil) {
        
        _userId = userId;
        _password = password;
        _domain = domain;
        _ha1String = nil;
        self.idInfo = @"SIP";
    }
    return self;
}


- (void)credentialProviderDidReceiveChallenge:(CSChallenge *)challenge
                            completionHandler:
(void (^)(CSUserCredential *credential))
completionHandler {
    
    if (challenge.hashCredentialSupported && !_ha1String && self.useHA1) {
        
        _ha1String = [self ha1ForRealm: challenge.realm];
    }
    if (!challenge.hashCredentialSupported && _password.length == 0) {
        
        NSLog(@"%s %@ %@ Missing password when hash value (%@) is not acceptable!",
              __PRETTY_FUNCTION__, self.idInfo, challenge, _ha1String);
        NSLog(@"%s Prompt user for credentials and save it for further processing in completionHandler", __PRETTY_FUNCTION__);
        [NotificationHelper displayMessageToUser: @"Implement Password prompt for user credentials" TAG: __PRETTY_FUNCTION__];
        completionHandler(nil);
        return;
    }
    
    CSUserCredential *cred = nil;
    if (challenge.hashCredentialSupported && _ha1String) {
        
        cred = [[CSUserCredential alloc] initWithUsername:_userId
                                                 password: nil
                                                   domain: _domain
                                                ha1String: _ha1String];
        
        NSLog(@"%s %@ %@ sending credentials userId:%@ domain:%@ ha1:%@",
              __PRETTY_FUNCTION__, self.idInfo, challenge, _userId, _domain, _ha1String);
    } else {
        cred = [[CSUserCredential alloc] initWithUsername: _userId
                                                 password: _password
                                                   domain: _domain
                                                ha1String: nil];
        NSLog(@"%s %@ %@ sending credentials userId:%@ domain:%@ password:%@",
              __PRETTY_FUNCTION__, self.idInfo, challenge, _userId, _domain, _password);
    }
    
    if (completionHandler) {
        
        completionHandler(cred);
    }
}

- (void)credentialProviderDidReceiveCredentialAccepted:(CSChallenge *)challenge {
    
    NSLog(@"%s %@ %@ credentials has been accepted for user: %@ password:%@ domain:%@ ha1:%@",
          __PRETTY_FUNCTION__, self.idInfo, challenge, _userId, _password, _domain, _ha1String);
}

- (void)credentialProviderDidReceiveChallengeCancelled:(CSChallenge *)challenge {
    
    NSLog(@"%s %@ %@ credentials request has been caceled",
          __PRETTY_FUNCTION__, self.idInfo, challenge);
}

- (BOOL)useHA1 {
    
    return YES;
}

- (NSString *)ha1ForRealm: (NSString *)realm {
    
    NSString *a1 = [NSString stringWithFormat: @"%@:%@:%@", _userId, realm, _password];
    
    unsigned char md5Hash[CC_MD5_DIGEST_LENGTH];
    CC_MD5(a1.UTF8String, (CC_LONG)strlen(a1.UTF8String), md5Hash);
    
    NSMutableString *result = [NSMutableString stringWithCapacity: CC_MD5_DIGEST_LENGTH*2];
    for (int i=0; i<CC_MD5_DIGEST_LENGTH; ++i) {
        
        [result appendFormat: @"%02x", md5Hash[i]];
    }
    return result;
}

@end
