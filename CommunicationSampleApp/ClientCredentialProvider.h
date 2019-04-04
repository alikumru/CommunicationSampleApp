/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>

@interface ClientCredentialProvider : NSObject <CSCredentialProvider>

@property (nonatomic, copy) NSString *idInfo;

- (instancetype)initWithUserId:(NSString *)userId
                      password:(NSString *)password
                     andDomain:(NSString *)domain;

- (instancetype)initWithUserId:(NSString *)userId
                      password:(NSString *)password
                        domain:(NSString *)domain
                  andHa1String:(NSString *)ha1String;


@end
