/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "NotificationHelper.h"
#import "AppDelegate.h"

@implementation NotificationHelper

+ (void) displayMessageToUser: (NSString *) msg TAG:(const char[])tag {
    
    NSLog(@"%s ATTENTION: %@", tag, msg);
    
    AppDelegate *delegate = (AppDelegate*) [[UIApplication sharedApplication] delegate];
    UIViewController *rootView = delegate.window.rootViewController;
    
    //Get to the rootViewController
    while(rootView.presentedViewController) {
        
        rootView = rootView.presentedViewController;
    }
    
    UIAlertController *attentionAlert = [UIAlertController alertControllerWithTitle:@"Attention" message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    //Define action for ok button on Alert
    UIAlertAction *acknowledge = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                            
                                                            //Dismiss alert window
                                                            [attentionAlert dismissViewControllerAnimated:NO completion:nil];
                                                        }];
    
    //Add action button on alert window
    [attentionAlert addAction:acknowledge];
    
    //Display alert view window
    [rootView presentViewController:attentionAlert animated:YES completion:nil];
}

+ (void) displayToastToUser: (NSString *) msg {
    
    NSLog(@"Toast: %@", msg);
    
    AppDelegate *delegate = (AppDelegate*) [[UIApplication sharedApplication] delegate];
    UIViewController *rootView = delegate.window.rootViewController;
    
    //Get to the rootViewController
    while(rootView.presentedViewController)
    {
        rootView = rootView.presentedViewController;
    }
    
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    
    //Display alert view window
    [rootView presentViewController:toast animated:YES completion:nil];
    
    int duration = 3; // duration in seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, duration * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

@end
