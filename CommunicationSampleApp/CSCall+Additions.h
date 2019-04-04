/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <AvayaClientServices/CSCall.h>


@interface CSCall (Additions)

@property (nonatomic) NSUUID *UUID;

- (NSString *)callDisplayName;

- (BOOL)isActive;
- (BOOL)isHeld;
- (BOOL)isFailed;

@end
