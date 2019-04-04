/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ContentSharingViewController.h"
#import "SDKManager.h"

@interface ContentSharingViewController ()

@property (nonatomic, strong) CSScreenSharingListener *screenSharingListener;

@end

@implementation ContentSharingViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    NSLog(@"%s contentSharing object received: [%@]", __PRETTY_FUNCTION__, self.contentSharing);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(collabSessionEndedRemotely:) name:kCollaborationSessionEndedRemotely object:nil];
    
    [self setupContentSharing];
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCollaborationSessionEndedRemotely object:nil];
}

- (void)collabSessionEndedRemotely:(NSNotification *)notification {
    
    self.screenSharingListener = nil;
    self.sharingView = nil;
    [self.navigationController popViewControllerAnimated:YES];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    
    return self.sharingView;
}

- (void) setupContentSharing {
    
    if (self.sharingView) {
        
        self.screenSharingListener= [[CSScreenSharingListener alloc] initWithFrame:CGRectZero];
        self.contentSharing.screenSharingListener = self.screenSharingListener;
        [self.sharingView setContentSharingDelegate:self.screenSharingListener];
        self.contentSharing.delegate = (id<CSContentSharingDelegate>)[SDKManager getInstance];
        self.screenSharingListener.drawingView = self.sharingView;
        self.sharingView.pauseImage = [UIImage imageNamed:@"pause_icon.png"];
        
        self.scrollView.delegate = self;
        self.scrollView.frame = self.sharingView.frame;
        [self.view addSubview:self.scrollView];
        self.scrollView.contentSize = self.contentSharing.screenSharingListener.contentSize;
        [self.scrollView addSubview:self.sharingView];
        
        // Set zoom scale so entire shared content fits in display area, view can be zoomed using pinch operation
        self.scrollView.zoomScale = 0.5;
    }
}

@end
