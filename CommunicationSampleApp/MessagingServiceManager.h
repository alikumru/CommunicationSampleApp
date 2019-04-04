/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import <Foundation/Foundation.h>
#import <AvayaClientServices/AvayaClientServices.h>
#import "Constants.h"

@interface MessagingServiceManager : NSObject
<CSMessagingAttachmentDelegate,
CSMessageDelegate,
CSMessagingConversationDelegate,
CSMessagingComposingParticipantsWatcherDelegate,
CSMessagingServiceDelegate,
CSMessagingAttachmentDelegate,
CSDataRetrievalWatcherDelegate>

- (instancetype)init __unavailable;
- (instancetype)initWithUser:(CSUser *)user;

@property (nonatomic, readonly) CSDataRetrievalWatcher *conversationsWatcher;

- (CSDataRetrievalWatcher *)messagesWatcherForConversationId:(NSString *)conversationId;

- (void)addMessageObject:(CSMessage *)message;
- (void)addConversationObject:(CSMessagingConversation *)conversation;

- (void)removeMessageObject:(CSMessage *)object;
- (void)removeConversationObject:(CSMessagingConversation *)object;

@end
