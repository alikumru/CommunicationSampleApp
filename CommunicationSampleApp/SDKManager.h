/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>
#import "MediaManager.h"
#import "MessagingServiceManager.h"
#import "Constants.h"
#import <CallKit/CallKit.h>


@interface SDKManager : NSObject<CSCallServiceDelegate, CSClientDelegate, CSDataRetrievalWatcherDelegate>

@property (nonatomic, strong) CSClient *client;

@property (nonatomic, strong) NSMutableArray *users;
@property (nonatomic, strong) NSMutableDictionary *calls;
@property (nonatomic, strong) NSMutableArray *contacts;
@property (nonatomic, readonly) CSCall *activeCall;
@property (nonatomic, strong) CSDataRetrievalWatcher *contactsRetrievalWatcher;
@property (nonatomic) CXProvider *callKitProvider;
@property (nonatomic) CXCallController *callKitController;
@property (nonatomic, copy) void (^waitingForActivation)(void);
@property (nonatomic) NSMutableArray *endCallActions;

@property (nonatomic, strong) MediaManager *mediaManager;
@property (nonatomic, strong) MessagingServiceManager *messagingServiceManager;
@property (nonatomic) BOOL callKitEnabled;

+ (instancetype)getInstance;
- (void)setupClient;
- (void)addUsersObject:(CSUser *)object;
- (void)removeUsersObject:(CSUser *)object;
- (void)addCallsObject:(CSCall *)object;
- (void)removeCallsObject:(CSCall *)object;
- (CSCall *)callForId: (NSUInteger)callId;
- (void)startCall:(CSCall *)call;
- (void)endCall:(CSCall *)call;
- (void)holdOrUnHoldCall:(CSCall *)call;

+ (NSString *)applicationVersion;
+ (NSString *)applicationBuildDate;
+ (NSString *)applicationBuildNumber;

@end

