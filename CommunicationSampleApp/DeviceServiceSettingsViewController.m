/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "DeviceServiceSettingsViewController.h"
#import "ConfigData.h"
#import "SDKManager.h"

@interface DeviceServiceSettingsViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation DeviceServiceSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ConfigData *configuration = [ConfigData getInstance];
    
    self.acsServerAddress.text =  configuration.acsServerAddress;
    self.acsPort.text = [NSString stringWithFormat:@"%d", configuration.acsPort];
    
    self.acsUsername.text =  configuration.acsUsername;
    self.acsPassword.text = configuration.acsPassword;
    
    [self.acsConnectionType setOn: configuration.acsConnectionTypeSecure animated:NO];
    
    if (configuration.acsLogin == ACSLoginStatusLoggedIn) {
        
        self.acsLoginStatusLabel.text =  @"Logged In";
    } else if (configuration.acsLogin == ACSLoginStatusLoggedOut) {
        
        self.acsLoginStatusLabel.text =  @"Not Logged In";
    }
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
    
    //Set delegate to hide keyBoard on iPhone
    [self.acsServerAddress setDelegate:self];
    [self.acsPort setDelegate:self];
    [self.acsUsername setDelegate: self];
    [self.acsPassword setDelegate: self];
}

- (void)dealloc {
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    
    [self.acsServerAddress resignFirstResponder];
    [self.acsPort resignFirstResponder];
    [self.acsUsername resignFirstResponder];
    [self.acsPassword resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    // Program cursor movement on 'Next' button press
    if (textField == self.acsServerAddress) {
        
        [textField resignFirstResponder];
        [self.acsUsername becomeFirstResponder];
    } else if (textField == self.acsPort) {
        
        [textField resignFirstResponder];
        [self.acsUsername becomeFirstResponder];
    } else if (textField == self.acsUsername) {
        
        [textField resignFirstResponder];
        [self.acsPassword becomeFirstResponder];
    } else if (textField == self.acsPassword) {
        
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)acsConnectionTypeBtn:(id)sender {
    
    if (self.acsConnectionType.on) {
        
        NSLog(@"%s set acs connection type to secure", __PRETTY_FUNCTION__);
        //configuration.acsConnectionTypeSecure = YES;
    } else {
        
        NSLog(@"%s set acs connection type to un-secure", __PRETTY_FUNCTION__);
        //configuration.acsConnectionTypeSecure = NO;
    }
}

- (IBAction)doneBtn:(id)sender {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    // Check if client is already logged in
    if (configuration.acsLogin == ACSLoginStatusLoggedOut) {
        
        NSLog(@"%s start acs login", __PRETTY_FUNCTION__);
        
        [self saveConfiguration];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            self.acsLoginStatusLabel.text =  @"Logging In";
            // Create user in async task
            [[SDKManager getInstance] setupClient];
        });
    } else if (configuration.acsLogin == ACSLoginStatusLoggedIn) {
        
        // Check if any configuration has changed before applying it
        if ([configuration.acsUsername isEqualToString:self.acsUsername.text] &
            [configuration.acsPassword isEqualToString:self.acsPassword.text] &
            [configuration.acsServerAddress isEqualToString:self.acsServerAddress.text] &
            (configuration.acsPort == self.acsPort.text.intValue) &
            (configuration.acsConnectionTypeSecure == self.acsConnectionType.on)) {
            
            NSLog(@"%s ACS already logged in, do nothing", __PRETTY_FUNCTION__);
        } else {
            
            NSLog(@"%s start new account login for acs", __PRETTY_FUNCTION__);
            
            [self saveConfiguration];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                self.acsLoginStatusLabel.text =  @"Logging In";
                // Create user in async task
                [[SDKManager getInstance] setupClient];
            });
        }
    } else {
        
        NSLog(@"%s User login is in progress, wait...", __PRETTY_FUNCTION__);
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveConfiguration {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    // Save current configuration in NSUserDefaults
    configuration.acsServerAddress = self.acsServerAddress.text;
    configuration.acsPort = self.acsPort.text.intValue;
    configuration.acsUsername = self.acsUsername.text;
    configuration.acsPassword = self.acsPassword.text;
    configuration.acsConnectionTypeSecure = self.acsConnectionType.on;
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    if (standardUserDefaults) {
        [standardUserDefaults setObject:self.acsServerAddress.text forKey:@"acsServerAddress"];
        [standardUserDefaults setInteger:self.acsPort.text.intValue forKey:@"acsPort"];
        [standardUserDefaults setObject:self.acsUsername.text forKey:@"acsUsername"];
        [standardUserDefaults setObject:self.acsPassword.text forKey:@"acsPassword"];
        [standardUserDefaults setBool:self.acsConnectionType.on forKey:@"acsConnectionTypeSecure"];
        [standardUserDefaults synchronize];
    }
}

@end
