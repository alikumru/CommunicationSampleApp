/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceSettingsViewController.h"
#import "SDKManager.h"
#import "ConfigData.h"

@interface MessagingServiceSettingsViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation MessagingServiceSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ConfigData *configuration = [ConfigData getInstance];
    
    self.messagingPollingInterval.layer.cornerRadius = 7;
    self.messagingPollingInterval.layer.borderWidth = 0.5f;
    self.messagingPollingInterval.layer.borderColor = [[UIColor lightGrayColor]CGColor];
    
    //Set delegate to hide keyBoard on iPhone
    self.messagingServerAddress.delegate = self;
    self.messagingPort.delegate = self;
    self.messagingUsername.delegate = self;
    self.messagingPassword.delegate = self;
    
    self.messagingServerAddress.text =  [configuration messagingServerAddress];
    self.messagingPort.text = [NSString stringWithFormat:@"%d", [configuration messagingPort]];
    
    self.messagingUsername.text =  [configuration messagingUsername];
    self.messagingPassword.text = [configuration messagingPassword];
    
    NSString *interval = @"";
    
    switch ([configuration messagingRefreshInterval]) {
            
        default:
        case CSMessagingRefreshModePush:
            interval = @"0 (Push)";
            break;
        case CSMessagingRefreshMode1Minute:
            interval = @"1";
            break;
        case CSMessagingRefreshMode2Minutes:
            interval = @"2";
            break;
        case CSMessagingRefreshMode5Minutes:
            interval = @"5";
            break;
        case CSMessagingRefreshMode15Minutes:
            interval = @"15";
            break;
        case CSMessagingRefreshMode60Minutes:
            interval = @"60";
            break;
        case CSMessagingRefreshModeManual:
            interval = @"Manual";
            break;
    }
    [self.messagingPollingInterval setTitle:interval forState:UIControlStateNormal];
    
    [self.messagingConnectionType setOn: configuration.messagingConnectionTypeSecure animated:NO];
    
    if (configuration.messagingLogin == MessagingLoginStatusLoggedIn) {
        
        self.messagingLoginStatusLabel.text =  @"Logged In";
    } else if (configuration.messagingLogin == MessagingLoginStatusLoggingIn) {
        
        self.messagingLoginStatusLabel.text =  @"Logging In";
    } else if (configuration.messagingLogin == MessagingLoginStatusLoggedOut) {
        
        self.messagingLoginStatusLabel.text =  @"Not Logged In";
    }
    
    //Hide keyboard once clicked outside of keyboard
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc {
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    
    [self.messagingServerAddress resignFirstResponder];
    [self.messagingPort resignFirstResponder];
    [self.messagingUsername resignFirstResponder];
    [self.messagingPassword resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    
    // Program cursor movement on 'Next' button press
    if (textField == self.messagingServerAddress) {
        
        [textField resignFirstResponder];
        [self.messagingUsername becomeFirstResponder];
    } else if (textField == self.messagingUsername) {
        
        [textField resignFirstResponder];
        [self.messagingPassword becomeFirstResponder];
    } else if (textField == self.messagingPassword) {
        
        [textField resignFirstResponder];
    }
    
    return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (int)parseMessagingRefreshInterval:(NSString *) parseInterval {
    
    int refreshInterval = CSMessagingRefreshModePush;
    
    if ([parseInterval isEqualToString:@"0 (Push)"]) {
        
        refreshInterval = CSMessagingRefreshModePush;
    } else if ([parseInterval isEqualToString:@"1"]) {
        
        refreshInterval = CSMessagingRefreshMode1Minute;
    } else if ([parseInterval isEqualToString:@"2"]) {
        
        refreshInterval = CSMessagingRefreshMode2Minutes;
    } else if ([parseInterval isEqualToString:@"5"]) {
        
        refreshInterval = CSMessagingRefreshMode5Minutes;
    } else if ([parseInterval isEqualToString:@"15"]) {
        
        refreshInterval = CSMessagingRefreshMode15Minutes;
    } else if ([parseInterval isEqualToString:@"60"]) {
        
        refreshInterval = CSMessagingRefreshMode60Minutes;
    } else if ([parseInterval isEqualToString:@"Manual"]) {
        
        refreshInterval = CSMessagingRefreshModeManual;
    }
    
    return refreshInterval;
}

- (IBAction)doneBtn:(id)sender {
    
    ConfigData *configuration = [ConfigData getInstance];
    
    // Check if client is already logged in
    if (configuration.messagingLogin == MessagingLoginStatusLoggedOut) {
        
        NSLog(@"%s start messaging login", __PRETTY_FUNCTION__);
        
        // Save current configuration in NSUserDefaults
        configuration.messagingServerAddress = self.messagingServerAddress.text;
        configuration.messagingPort = self.messagingPort.text.intValue;
        configuration.messagingRefreshInterval = [self parseMessagingRefreshInterval:self.messagingPollingInterval.titleLabel.text];
        configuration.messagingUsername = self.messagingUsername.text;
        configuration.messagingPassword = self.messagingPassword.text;
        configuration.messagingConnectionTypeSecure = self.messagingConnectionType.on;
        
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        
        if (standardUserDefaults) {
            [standardUserDefaults setObject:self.messagingServerAddress.text forKey:@"messagingServerAddress"];
            [standardUserDefaults setInteger:self.messagingPort.text.intValue forKey:@"messagingPort"];
            [standardUserDefaults setInteger:[self parseMessagingRefreshInterval:self.messagingPollingInterval.titleLabel.text] forKey:@"messagingRefreshInterval"];
            [standardUserDefaults setObject:self.messagingUsername.text forKey:@"messagingUsername"];
            [standardUserDefaults setObject:self.messagingPassword.text forKey:@"messagingPassword"];
            [standardUserDefaults setBool:configuration.messagingConnectionTypeSecure forKey:@"messagingConnectionTypeSecure"];
            [standardUserDefaults synchronize];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            
            self.messagingLoginStatusLabel.text =  @"Logging In";
            // Create user in async task
            [[SDKManager getInstance] setupClient];
        });
    } else if (configuration.messagingLogin == MessagingLoginStatusLoggedIn) {
        
        // Check if any configuration has changed before applying it
        if ([configuration.messagingUsername isEqualToString:self.messagingUsername.text] &
            [configuration.messagingPassword isEqualToString:self.messagingPassword.text] &
            [configuration.messagingServerAddress isEqualToString:self.messagingServerAddress.text] &
            (configuration.messagingPort == self.messagingPort.text.intValue) &
            (configuration.messagingRefreshInterval == [self parseMessagingRefreshInterval:self.messagingPollingInterval.titleLabel.text]) &
            (configuration.messagingConnectionTypeSecure == self.messagingConnectionType.on)) {
            
            NSLog(@"%s Messaging already logged in, do nothing", __PRETTY_FUNCTION__);
        } else {
            
            NSLog(@"%s start new account login for messaging", __PRETTY_FUNCTION__);
            
            // Save current configuration in NSUserDefaults
            configuration.messagingServerAddress = self.messagingServerAddress.text;
            configuration.messagingPort = self.messagingPort.text.intValue;
            configuration.messagingRefreshInterval = [self parseMessagingRefreshInterval:self.messagingPollingInterval.titleLabel.text];
            configuration.messagingUsername = self.messagingUsername.text;
            configuration.messagingPassword = self.messagingPassword.text;
            configuration.messagingConnectionTypeSecure = self.messagingConnectionType.on;
            
            NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
            
            if (standardUserDefaults) {
                [standardUserDefaults setObject:self.messagingServerAddress.text forKey:@"messagingServerAddress"];
                [standardUserDefaults setInteger:self.messagingPort.text.intValue forKey:@"messagingPort"];
                [standardUserDefaults setInteger:[self parseMessagingRefreshInterval:self.messagingPollingInterval.titleLabel.text] forKey:@"messagingRefreshInterval"];
                [standardUserDefaults setObject:self.messagingUsername.text forKey:@"messagingUsername"];
                [standardUserDefaults setObject:self.messagingPassword.text forKey:@"messagingPassword"];
                [standardUserDefaults setBool:configuration.messagingConnectionTypeSecure forKey:@"messagingConnectionTypeSecure"];
                [standardUserDefaults synchronize];
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                
                self.messagingLoginStatusLabel.text =  @"Logging In";
                // Create user in async task
                [[SDKManager getInstance] setupClient];
            });
        }
    } else {
        
        NSLog(@"%s User login is in progress, wait...", __PRETTY_FUNCTION__);
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)messagingConnectionTypeBtn:(id)sender {
    
    ConfigData *configuration = [ConfigData getInstance];
    if (self.messagingConnectionType.on) {
        
        NSLog(@"%s set messaging connection type to secure", __PRETTY_FUNCTION__);
        configuration.messagingConnectionTypeSecure = YES;
    } else {
        
        NSLog(@"%s set messaging connection type to un-secure", __PRETTY_FUNCTION__);
        configuration.messagingConnectionTypeSecure = NO;
    }
}

- (IBAction)messagingPollingIntervalBtn:(id)sender {
    
    //Set up alert window
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Refresh Interval" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    //Define action for items in Alert
    UIAlertAction *push = [UIAlertAction
                           actionWithTitle:@"0 (Push)"
                           style:UIAlertActionStyleDefault
                           handler:^(UIAlertAction * action)
                           {
                               [self.messagingPollingInterval setTitle:@"0 (Push)" forState:UIControlStateNormal];
                           }];
    
    UIAlertAction *oneMinute = [UIAlertAction
                                actionWithTitle:@"1"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action)
                                {
                                    [self.messagingPollingInterval setTitle:@"1" forState:UIControlStateNormal];
                                }];
    
    UIAlertAction *twoMinute = [UIAlertAction
                                actionWithTitle:@"2"
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action)
                                {
                                    [self.messagingPollingInterval setTitle:@"2" forState:UIControlStateNormal];
                                }];
    
    UIAlertAction *fiveMinute = [UIAlertAction
                                 actionWithTitle:@"5"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     [self.messagingPollingInterval setTitle:@"5" forState:UIControlStateNormal];
                                 }];
    
    UIAlertAction *fifteenMinute = [UIAlertAction
                                    actionWithTitle:@"15"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action)
                                    {
                                        [self.messagingPollingInterval setTitle:@"15" forState:UIControlStateNormal];
                                    }];
    
    UIAlertAction *sixtyMinute = [UIAlertAction
                                  actionWithTitle:@"60"
                                  style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * action)
                                  {
                                      [self.messagingPollingInterval setTitle:@"60" forState:UIControlStateNormal];
                                  }];
    
    UIAlertAction *manual = [UIAlertAction
                             actionWithTitle:@"Manual"
                             style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction * action)
                             {
                                 [self.messagingPollingInterval setTitle:@"Manual" forState:UIControlStateNormal];
                             }];
    
    UIAlertAction *cancel = [UIAlertAction
                             actionWithTitle:@"Cancel"
                             style:UIAlertActionStyleCancel
                             handler:^(UIAlertAction * action)
                             {
                                 [self dismissViewControllerAnimated:YES completion:nil];
                             }];
    
    //Add action buttons on alert window
    [alert addAction:push];
    [alert addAction:oneMinute];
    [alert addAction:twoMinute];
    [alert addAction:fiveMinute];
    [alert addAction:fifteenMinute];
    [alert addAction:sixtyMinute];
    [alert addAction:manual];
    [alert addAction:cancel];
    
    // set the alertController's popoverPresentationController
    alert.popoverPresentationController.sourceView = self.view;
    alert.popoverPresentationController.sourceRect = self.messagingPollingInterval.frame;
    
    //Display alert window
    [self presentViewController:alert animated:YES completion:nil];
}

@end
