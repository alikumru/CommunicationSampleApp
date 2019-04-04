/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>
#import "MediaManager.h"
#import "Constants.h"


@interface SDKManager : NSObject<CSCallServiceDelegate, CSClientDelegate, CSDataRetrievalWatcherDelegate>

@property (nonatomic, strong) CSClient *client;

@property (nonatomic, strong) CSUser *user;
@property (nonatomic, readonly) CSCall *activeCall;
@property (nonatomic) NSMutableArray *endCallActions;

@property (nonatomic, strong) MediaManager *mediaManager;

+ (instancetype)getInstance;
- (void)setupClient;
- (void)endCall:(CSCall *)call;
- (void)holdOrUnHoldCall:(CSCall *)call;

+ (NSString *)applicationVersion;
+ (NSString *)applicationBuildDate;
+ (NSString *)applicationBuildNumber;

@end

