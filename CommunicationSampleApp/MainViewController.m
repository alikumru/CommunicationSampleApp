/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MainViewController.h"
#import "SDKManager.h"
#import "ConfigData.h"

@interface MainViewController ()

@end

@implementation MainViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    ConfigData *configuration = [ConfigData getInstance];
    
    if (configuration.sipLogin == SipLoginStatusLoggedIn) {
        
        self.callServiceLabel.enabled = YES;
        self.callLogsLabel.enabled = YES;
        self.contactsServiceLabel.enabled = YES;
    } else {
        
        self.callServiceLabel.enabled = NO;
        self.callLogsLabel.enabled = NO;
        self.contactsServiceLabel.enabled = NO;
    }
    
    if (configuration.acsEnabled) {
        
        if (configuration.acsLogin == ACSLoginStatusLoggedIn) {
            
            self.contactsServiceLabel.enabled = YES;
        } else {
            
            self.contactsServiceLabel.enabled = NO;
        }
    }
    
    if (configuration.messagingLogin == MessagingLoginStatusLoggedIn) {
        
        self.messagingServiceLabel.enabled = YES;
    } else {
        
        self.messagingServiceLabel.enabled = NO;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startRegistration:) name:kStartSIPLoginNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kRefreshWindowNotification object:nil];
    
    // Start auto-login if client is in logged out state and previous configuration is available
    if ((configuration.sipLogin == SipLoginStatusLoggedOut && configuration.sipUsername.length > 0) ||
        (configuration.acsLogin == ACSLoginStatusLoggedOut && configuration.acsUsername.length > 0) ||
        (configuration.messagingLogin == MessagingLoginStatusLoggedOut && configuration.messagingUsername.length > 0)) {
        
        NSLog(@"%s start user auto-login", __PRETTY_FUNCTION__);
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            // Create user in async task
            [[SDKManager getInstance] setupClient];
        });
    }
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kStartSIPLoginNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRefreshWindowNotification object:nil];
}

- (void)setBorderWidth:(UIButton *)btn
{
    btn.layer.borderWidth = 0.5f;
    btn.layer.borderColor = [[UIColor blackColor]CGColor];
}

- (IBAction)callServiceBtn:(id)sender {
}

- (IBAction)contactsServiceBtn:(id)sender {
}

- (IBAction)callLogsBtn:(id)sender {
}

- (void)refresh:(NSNotification *)notification {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    if (configuration.sipLogin == SipLoginStatusLoggedIn) {
        
        self.callServiceLabel.enabled = YES;
        self.callLogsLabel.enabled = YES;
        self.contactsServiceLabel.enabled = YES;
    } else {
        
        self.callServiceLabel.enabled = NO;
        self.callLogsLabel.enabled = NO;
        self.contactsServiceLabel.enabled = NO;
    }
    
    if (configuration.acsEnabled) {
        
        if (configuration.acsLogin == ACSLoginStatusLoggedIn) {
            
            self.contactsServiceLabel.enabled = YES;
        } else {
            
            self.contactsServiceLabel.enabled = NO;
        }
    }
    
    if (configuration.messagingLogin == MessagingLoginStatusLoggedIn) {
        
        self.messagingServiceLabel.enabled = YES;
    } else {
        
        self.messagingServiceLabel.enabled = NO;
    }
}

- (void)startRegistration:(NSNotification *)notification {
    
    NSLog(@"===> user created successfully... Now start registration");
    for (CSUser *user in [SDKManager getInstance].users) {
        
        [user.contactService setDelegate:(id<CSContactServiceDelegate>)[SDKManager getInstance]];
        [user start];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
