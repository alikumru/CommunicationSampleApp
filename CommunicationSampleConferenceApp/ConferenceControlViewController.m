/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ConferenceControlViewController.h"
#import "NotificationHelper.h"

@interface ConferenceControlViewController ()

@end

@implementation ConferenceControlViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.lockMeetingBtnLabel.on = self.conferenceCall.isLocked;
    self.muteAllBtnLabel.enabled = self.conferenceCall.muteAllParticipantsCapability.allowed;
    self.unMuteAllBtnLabel.enabled = self.conferenceCall.unmuteAllParticipantsCapability.allowed;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)lockMeetingBtn:(id)sender {
    
    if (self.conferenceCall.isLocked) {
        
        NSLog(@"%s Unlock the conference", __PRETTY_FUNCTION__);
        
        [self.conferenceCall setLocked:NO completionHandler:^(NSError *error) {
            
            if (error) {
                
                [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while unlocking confernce, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
            } else {
                
                NSLog(@"%s Conference unlocked successfully", __PRETTY_FUNCTION__);
            }
        }];
        
    } else {
        
        NSLog(@"%s Lock the conference", __PRETTY_FUNCTION__);
        
        [self.conferenceCall setLocked:YES completionHandler:^(NSError *error) {
            
            if (error) {
                
                [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while locking confernce, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
            } else {
                
                NSLog(@"%s Conference Locked successfully", __PRETTY_FUNCTION__);
            }
        }];
    }
}

- (IBAction)muteAllBtn:(id)sender {
    
    NSLog(@"%s Mute All participants", __PRETTY_FUNCTION__);
    
    [self.conferenceCall muteAllParticipantsWithCompletionHandler:^(NSError *error) {
        
        if (error) {
            
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while muting Audio of the conference, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s All participants muted", __PRETTY_FUNCTION__);
        }
    }];
}

- (IBAction)unMuteAllBtn:(id)sender {
    
    NSLog(@"%s Unmute All participants", __PRETTY_FUNCTION__);
    
    [self.conferenceCall unmuteAllParticipantsWithCompletionHandler:^(NSError *error) {
        
        if (error) {
            
            [NotificationHelper displayMessageToUser:[NSString stringWithFormat:@"Error while unmuting Audio of the conference, Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG: __PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s All participants unmuted", __PRETTY_FUNCTION__);
        }
    }];
}
@end
