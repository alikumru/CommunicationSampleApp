/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "AboutViewController.h"
#import "SDKManager.h"

@interface AboutViewController ()

@end

@implementation AboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appVersionLabel.text = [NSString stringWithFormat:@"%@ Build %@", [SDKManager applicationVersion], [SDKManager applicationBuildNumber]];
    self.appBuildDateLabel.text = [SDKManager applicationBuildDate];
    self.sdkVersionLabel.text = [CSClient versionString];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
