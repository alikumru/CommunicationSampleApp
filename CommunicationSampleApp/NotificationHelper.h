/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

@interface NotificationHelper : NSObject

+ (void)displayMessageToUser:(NSString *)msg TAG:(const char[])tag;
+ (void)displayToastToUser:(NSString *)msg;

@end
