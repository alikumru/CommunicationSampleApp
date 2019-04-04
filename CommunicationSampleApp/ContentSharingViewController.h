/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <UIKit/UIKit.h>
#import "SDKManager.h"
#import "AvayaClientServices/AvayaClientServices.h"

@interface ContentSharingViewController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, strong) IBOutlet CSIOSScreenSharingView *sharingView;
@property (nonatomic, strong) CSContentSharing *contentSharing;
@property (nonatomic, strong) CSCollaboration *collab;
@property (nonatomic, strong) IBOutlet UIScrollView *scrollView;

@end
