/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "CallServiceSettingsViewController.h"
#import "ConfigData.h"
#import "SDKManager.h"

@interface CallServiceSettingsViewController ()

@end

@implementation CallServiceSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ConfigData *configuration = [ConfigData getInstance];
    
    //Set delegate to hide keyBoard on iPhone
    [self.sipProxyAddress setDelegate:self];
    [self.sipProxyPort setDelegate:self];
    [self.sipUsername setDelegate: self];
    [self.sipPassword setDelegate: self];
    [self.sipDomain setDelegate:self];
    //test change 2
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(startRegistration:) name:kStartSIPLoginNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(transportChanged:) name:kSIPTransportChangedNotification object:nil];
    
    self.sipProxyAddress.text = configuration.sipProxyAddress;
    self.sipProxyPort.text = [NSString stringWithFormat:@"%d", configuration.sipProxyPort];
    self.sipDomain.text=configuration.sipDomain;
    [self.tlsSwitch setOn: ([configuration.sipTransport compare:@"TLS"] == NSOrderedSame) ? YES : NO animated:NO];
    self.sipUsername.text = configuration.sipUsername;
    self.sipPassword.text = configuration.sipPassword;
    [self.callKitSwitch setOn:configuration.callKitEnabled animated:NO];
    
    if (configuration.sipLogin==SipLoginStatusLoggedIn) {
        
        self.sipLoginStatus.text =  @"Logged In";
    } else if (configuration.sipLogin==SipLoginStatusLoggingIn) {
        
        self.sipLoginStatus.text =  @"Logging In";
    } else if (configuration.sipLogin==SipLoginStatusLoggedOut) {
        
        self.sipLoginStatus.text =  @"Not Logged In";
    }
    
    // Disable fields when opening this screen when user is Logging in
    if (([ConfigData getInstance].sipLogin == SipLoginStatusLoggingIn)) {
        
        self.sipProxyAddress.enabled = NO;
        self.sipProxyPort.hidden = NO;
        self.sipProxyPort.enabled = NO;
        self.tlsSwitch.enabled = NO;
        self.sipDomain.enabled = NO;
        
        self.sipUsername.enabled = NO;
        self.sipPassword.enabled = NO;
        self.callKitSwitch.enabled = NO;
        
        self.sipLoginStatus.text =  @"Logging In";
    }
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kStartSIPLoginNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSIPTransportChangedNotification object:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    // Program cursor movement on 'Next' button press
    if (textField == self.sipProxyAddress) {
        
        [textField resignFirstResponder];
        [self.sipDomain becomeFirstResponder];
    } else if (textField == self.sipDomain) {
        
        [textField resignFirstResponder];
        [self.sipUsername becomeFirstResponder];
    } else if (textField == self.sipUsername) {
        
        [textField resignFirstResponder];
        [self.sipPassword becomeFirstResponder];
    } else if (textField == self.sipPassword) {
        
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (IBAction)doneBtn:(id)sender {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    // Check if client is logged in
    if (configuration.sipLogin == SipLoginStatusLoggedOut) {
        
        NSLog(@"%s start user login", __PRETTY_FUNCTION__);
        
        [self saveConfiguration];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            self.sipLoginStatus.text =  @"Logging In";
            // Create user in async task
            [[SDKManager getInstance] setupClient];
        });
    }else if ([ConfigData getInstance].sipLogin == SipLoginStatusLoggedIn) {
        
        // Check if any configuration has changed before applying it
        if ([configuration.sipUsername isEqualToString:self.sipUsername.text] &&
            [configuration.sipPassword isEqualToString:self.sipPassword.text] &&
            [configuration.sipDomain isEqualToString:self.sipDomain.text] &&
            [configuration.sipProxyAddress isEqualToString:self.sipProxyAddress.text] &&
            (configuration.sipProxyPort == self.sipProxyPort.text.intValue) &&
            (configuration.callKitEnabled == [self.callKitSwitch isOn])) {
            
            NSLog(@"%s User already logged in, do nothing", __PRETTY_FUNCTION__);
        } else {
            
            NSLog(@"%s start new user login", __PRETTY_FUNCTION__);
            
            [self saveConfiguration];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                self.sipLoginStatus.text =  @"Logging In";
                // Create user in async task
                [[SDKManager getInstance] setupClient];
            });
        }
    } else {
        
        NSLog(@"%s User login is in progress, wait...", __PRETTY_FUNCTION__);
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)tlsBtn:(id)sender {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    if (self.tlsSwitch.on) {
        
        NSLog(@"%s set transport type to TLS", __PRETTY_FUNCTION__);
        configuration.sipTransport = @"TLS";
        configuration.sipProxyPort = 5061;
    } else {
        
        NSLog(@"%s set transport type to TCP", __PRETTY_FUNCTION__);
        configuration.sipTransport = @"TCP";
        configuration.sipProxyPort = 5060;
    }
    // Send Notification to update secreen
    [[NSNotificationCenter defaultCenter] postNotificationName:kSIPTransportChangedNotification object:nil];
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

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    
    self.activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    
    self.activeField = nil;
}

// Called when the SIP Transport switch changes it's state.
- (void)transportChanged:(NSNotification*)aNotification {
    
    self.sipProxyPort.text = [NSString stringWithFormat:@"%d", [[ConfigData getInstance] sipProxyPort]];
}

- (void)saveConfiguration {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    // Save current configuration in NSUserDefaults
    configuration.sipProxyAddress = self.sipProxyAddress.text;
    configuration.sipProxyPort = self.sipProxyPort.text.intValue;
    configuration.sipDomain = self.sipDomain.text;
    configuration.sipUsername = self.sipUsername.text;
    configuration.sipPassword = self.sipPassword.text;
    configuration.callKitEnabled = [self.callKitSwitch isOn];
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardUserDefaults) {
        
        [standardUserDefaults setObject:self.sipProxyAddress.text forKey:@"sipProxyAddress"];
        [standardUserDefaults setInteger:self.sipProxyPort.text.intValue forKey:@"sipProxyPort"];
        [standardUserDefaults setObject:self.sipDomain.text forKey:@"sipDomain"];
        [standardUserDefaults setObject:self.sipUsername.text forKey:@"sipUsername"];
        [standardUserDefaults setObject:self.sipPassword.text forKey:@"sipPassword"];
        [standardUserDefaults setBool: [self.callKitSwitch isOn] forKey:@"callKitEnabled"];
        
        [standardUserDefaults synchronize];
    }
}

@end
