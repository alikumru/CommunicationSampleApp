/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>

@interface MainViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIButton *callServiceLabel;
@property (nonatomic, weak) IBOutlet UIButton *contactsServiceLabel;
@property (nonatomic, weak) IBOutlet UIButton *callLogsLabel;
@property (nonatomic, weak) IBOutlet UIButton *messagingServiceLabel;

- (IBAction)callServiceBtn:(id)sender;
- (IBAction)contactsServiceBtn:(id)sender;
- (IBAction)callLogsBtn:(id)sender;

@end

