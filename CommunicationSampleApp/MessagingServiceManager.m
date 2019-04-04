/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "MessagingServiceManager.h"
#import "ConfigData.h"
#import "NotificationHelper.h"

////////////////////////////////////////////////////////////////////////////////

@interface MessagingServiceManager()

@property (nonatomic, strong) NSMutableDictionary *messages;
@property (nonatomic, strong) NSMutableDictionary *conversations;
@property (nonatomic, strong) CSDataRetrievalWatcher *conversationsWatcher;
@property (nonatomic, strong) NSMutableDictionary *messageWatchers;
@property (nonatomic, strong) CSUser *user;

@end

////////////////////////////////////////////////////////////////////////////////

@implementation MessagingServiceManager

- (instancetype)initWithUser:(CSUser *)user {
    
    if (!user || !user.messagingService) {
        
        return nil;
    }
    
    if (self = [super init]) {
        
        self.conversations = [NSMutableDictionary dictionary];
        self.messages = [NSMutableDictionary dictionary];
        self.conversationsWatcher = nil;
        self.messageWatchers = [NSMutableDictionary dictionary];
        self.user = user;
        self.user.messagingService.delegate = self;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////

- (void)dealloc {
    
    for (NSString* messageId in self.messages) {
        CSMessage *message = self.messages[messageId];
        if (message) {
            message.delegate = nil;
        }
    }
    
    for (NSString* conversationId in self.conversations) {
        CSMessagingConversation *conversation = self.conversations[conversationId];
        if (conversation) {
            conversation.delegate = nil;
            conversation.composingParticipantsWatcherDelegate = nil;
        }
    }
    
    self.user.messagingService.delegate = nil;
}

////////////////////////////////////////////////////////////////////////////////

- (CSMessagingService *)messagingService {
    
    return self.user.messagingService;
}

////////////////////////////////////////////////////////////////////////////////

- (void)addConversationObject:(CSMessagingConversation *)object {
    
    object.delegate = self;
    object.composingParticipantsWatcherDelegate = self;
    self.conversations[object.conversationId] = object;
    
    // Create a watcher for this conversation's messages.
    CSDataRetrievalWatcher* watcher = [[CSDataRetrievalWatcher alloc] init];
    self.messageWatchers[object.conversationId] = watcher;
    [watcher addDelegate:self];
    [object retrieveMessagesWithWatcher:watcher];
}

////////////////////////////////////////////////////////////////////////////////

- (void)removeConversationObject:(CSMessagingConversation *)object {
    
    object.delegate = nil;
    object.composingParticipantsWatcherDelegate = nil;
    [object retrieveMessagesWithWatcher:nil];
    [self.conversations removeObjectForKey: (object.conversationId)];
}

////////////////////////////////////////////////////////////////////////////////

- (void)addMessageObject:(CSMessage *)object {
    
    object.delegate = self;
    self.messages[object.messageId] = object;
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationNotification object:nil];
}

////////////////////////////////////////////////////////////////////////////////

- (void)removeMessageObject:(CSMessage *)object {
    
    object.delegate = nil;
    [self.messages removeObjectForKey:(object.messageId)];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationNotification object:nil];
}

////////////////////////////////////////////////////////////////////////////////

- (CSDataRetrievalWatcher *)messagesWatcherForConversationId:(NSString *)conversationId {
    return [self.messageWatchers objectForKey:conversationId];
}

////////////////////////////////////////////////////////////////////////////////

- (NSArray *)messagesCacheForConversationId:(NSString *)conversationId {
    CSDataRetrievalWatcher* watcher = [self.messageWatchers objectForKey:conversationId];
    if (watcher) {
        return watcher.snapshot;
    }
    return nil;
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSMessagingAttachmentDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeName:(NSString *)name {
    NSLog(@"%s Attachment ID %@ name: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, name);
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeIsThumbnail:(BOOL)IsThumbnail {
    NSLog(@"%s Attachment ID %@ isThumbnail: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, IsThumbnail ? @"Yes" : @"No");
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeIsGeneratedContent:(BOOL)isGeneratedContent {
    NSLog(@"%s Attachment ID %@ isGeneratedContent: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, isGeneratedContent ? @"Yes" : @"No");
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeLocation:(NSString *)location {
    NSLog(@"%s Attachment ID %@ location: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, location);
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeMimeType:(NSString *)mimeType {
    NSLog(@"%s Attachment ID %@ MIME type: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, mimeType);
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeAttachmentThumbnail:(CSMessagingAttachment *)attachmentThumbnail {
    NSLog(@"%s Attachment ID %@ thumbnail changed. New thumbnail ID: %@", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, attachmentThumbnail.attachmentId);
}

- (void)messagingAttachment:(CSMessagingAttachment *)messagingAttachment didChangeStatus:(CSMessagingAttachmentStatus)status {
    NSLog(@"%s Attachment ID %@ status changed: %ld", __PRETTY_FUNCTION__, messagingAttachment.attachmentId, (long)status);
    [[NSNotificationCenter defaultCenter] postNotificationName:kAttachmentReceivedNotification object:nil];
}

- (void)messagingAttachmentDidChangeCapabilities:(CSMessagingAttachment *)messagingAttachment {
    NSLog(@"%s Attachment ID %@ capabilities changed", __PRETTY_FUNCTION__, messagingAttachment.attachmentId);
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSMessageDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)message:(CSMessage *)message didChangeType:(CSMessagingType)type {
    NSLog(@"%s Message ID %@ type changed: %ld", __PRETTY_FUNCTION__, message.messageId, (long)type);
}

- (void)message:(CSMessage *)message didChangeBody:(NSString *)body {
    NSLog(@"%s Message ID %@ body changed: %@", __PRETTY_FUNCTION__, message.messageId, body);
}

- (void)message:(CSMessage *)message didChangeInReplyTo:(CSMessage *)newMessage {
    NSLog(@"%s Message ID %@ 'in reply to' changed: Message ID %@", __PRETTY_FUNCTION__, message.messageId, newMessage.messageId);
}

- (void)message:(CSMessage *)message didChangeLastModifiedDate:(NSDate *)date {
    NSLog(@"%s Message ID %@ last modification date changed: %@", __PRETTY_FUNCTION__, message.messageId, date);
}

- (void)message:(CSMessage *)message didChangeIsCoalescedStatus:(BOOL)isCoalesced {
    NSLog(@"%s Message ID %@ 'is coalesced' status: %@", __PRETTY_FUNCTION__, message.messageId, isCoalesced ? @"Yes" : @"No");
}

- (void)message:(CSMessage *)message didChangeHasAttachmentStatus:(BOOL)hasAttachment {
    NSLog(@"%s Message ID %@ 'has attachment' status: %@", __PRETTY_FUNCTION__, message.messageId, hasAttachment ? @"Yes" : @"No");
}

- (void)message:(CSMessage *)message didChangeHasUnviewedAttachmentStatus:(BOOL)hasUnviewedAttachment {
    NSLog(@"%s Message ID %@ 'has unviewed attachment' status: %@", __PRETTY_FUNCTION__, message.messageId, hasUnviewedAttachment ? @"Yes" : @"No");
    [[NSNotificationCenter defaultCenter] postNotificationName:kAttachmentReceivedNotification object:nil];
}

- (void)message:(CSMessage *)message didChangeIsPrivateStatus:(BOOL)isPrivate {
    NSLog(@"%s Message ID %@ 'is private' status: %@", __PRETTY_FUNCTION__, message.messageId, isPrivate ? @"Yes" : @"No");
}

- (void)message:(CSMessage *)message didChangeDoNotForwardStatus:(BOOL)doNotForward {
    NSLog(@"%s Message ID %@ 'do not forward' status: %@", __PRETTY_FUNCTION__, message.messageId, doNotForward ? @"Yes" : @"No");
}

- (void)message:(CSMessage *)message didChangeIsReadStatus:(BOOL)isRead {
    NSLog(@"%s Message ID %@ 'is read' status: %@", __PRETTY_FUNCTION__, message.messageId, isRead ? @"Yes" : @"No");
}

- (void)message:(CSMessage *)message didChangeImportance:(CSMessagingImportance)importance {
    NSLog(@"%s Message ID %@ importance: %lu", __PRETTY_FUNCTION__, message.messageId, (unsigned long)importance);
}

- (void)message:(CSMessage *)message didChangeSensitivity:(CSMessagingSensitivityLevel)sensitivityLevel {
    NSLog(@"%s Message ID %@ sensitivity: %lu", __PRETTY_FUNCTION__, message.messageId, (unsigned long)sensitivityLevel);
}

- (void)messageDidChangeCapabilities:(CSMessage *)message {
    NSLog(@"%s Message ID %@ capabilities changed", __PRETTY_FUNCTION__, message.messageId);
}

- (void)message:(CSMessage *)message didChangeHasUnreadAttachmentStatus:(BOOL)hasUnreadAttachment {
    
    NSLog(@"%s Message ID %@ has unread attachments: %@", __PRETTY_FUNCTION__, message.messageId, hasUnreadAttachment ? @"Yes" : @"No");
    [[NSNotificationCenter defaultCenter] postNotificationName:kAttachmentReceivedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationNotification object:nil];
}

- (void)message:(CSMessage *)message didChangeStatus:(CSMessagingMessageStatus)status {
    NSLog(@"%s Message ID %@ has changed status: %ld", __PRETTY_FUNCTION__, message.messageId, (long)status);
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSMessagingConversationDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeActiveStatus:(BOOL)isActive {
    NSLog(@"%s Conversation ID %@ active: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], isActive ? @"Yes" : @"No");
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeClosedStatus:(BOOL)isClosed {
    NSLog(@"%s Conversation ID %@ closed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], isClosed ? @"Yes" : @"No");
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeMultiPartyStatus:(BOOL)isMultiParty {
    NSLog(@"%s Conversation ID %@ multi-party: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], isMultiParty ? @"Yes" : @"No");
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeLastAccessedTime:(NSDate *)time {
    NSLog(@"%s Conversation ID %@ last accessed time changed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], time);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeLastUpdatedTime:(NSDate *)time {
    NSLog(@"%s Conversation ID %@ last updated time changed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], time);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeLatestEntryTime:(NSDate *)time {
    NSLog(@"%s Conversation ID %@ latest entry time changed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], time);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangePreviewText:(NSString *)previewText {
    NSLog(@"%s Conversation ID %@ preview text changed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], previewText);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeTotalMessageCount:(NSUInteger)totalMsgCount {
    NSLog(@"%s Conversation ID %@ total message count changed: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)totalMsgCount);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeTotalAttachmentCount:(NSUInteger)totalAttachmentCount {
    NSLog(@"%s Conversation ID %@ total attachemnt count changed: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)totalAttachmentCount);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeTotalUnreadMessageCount:(NSUInteger)totalUnreadMsgCount{
    NSLog(@"%s Conversation ID %@ total unread message count changed: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)totalUnreadMsgCount);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeTotalUnviewedAttachmentCount:(NSUInteger)totalUnviewedAttachmentCount {
    NSLog(@"%s Conversation ID %@ total unviewed attachment count changed: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)totalUnviewedAttachmentCount);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeSensitivity:(CSMessagingSensitivityLevel)sensitivity {
    NSLog(@"%s Conversation ID %@ sensitivity changed: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)sensitivity);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeSubject:(NSString *)subject {
    NSLog(@"%s Conversation ID %@ subject changed: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], subject);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeType:(CSMessagingConversationType)conversationType {
    NSLog(@"%s Conversation ID %@ type changed: %ld", __PRETTY_FUNCTION__, [messagingConversation conversationId], (long)conversationType);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didAddMessages:(NSArray *)messages {
    
    for (CSMessage *message in messages) {
        [self addMessageObject:message];
        NSLog(@"%s Conversation ID %@ added message with ID: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], [message  messageId]);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationListNotification object:nil];
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didRemoveMessages:(NSArray *)messages {
    
    for (CSMessage *message in messages) {
        [self removeMessageObject:message];
        NSLog(@"%s Conversation ID %@ removed message with ID: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], [message  messageId]);
    }
}

- (void)messagingConversationDidChangeCapabilities:(CSMessagingConversation *)messagingConversation {
    NSLog(@"%s Conversation ID %@ capabilities changed", __PRETTY_FUNCTION__, [messagingConversation conversationId]);
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationListNotification object:nil];
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didAddParticipants:(NSArray *)participants {
    for (CSMessagingParticipant *participant in participants) {
        NSLog(@"%s Conversation ID %@ added participant: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], participant.address);
    }
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didRemoveParticipants:(NSArray *)participants {
    for (CSMessagingParticipant *participant in participants) {
        NSLog(@"%s Conversation ID %@ removed participant: %@", __PRETTY_FUNCTION__, [messagingConversation conversationId], participant.address);
    }
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeStatus:(CSMessagingConversationStatus)status {
    NSLog(@"%s Conversation ID %@ status changed to: %ld", __PRETTY_FUNCTION__, [messagingConversation conversationId], (long)status);
}

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeTotalUnreadAttachmentCount:(NSUInteger)totalUnreadAttachmentCount {
    NSLog(@"%s Conversation ID %@ status changed to: %lu", __PRETTY_FUNCTION__, [messagingConversation conversationId], (unsigned long)totalUnreadAttachmentCount);
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSMessagingComposingParticipantsWatcherDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)messagingConversation:(CSMessagingConversation *)messagingConversation didChangeComposingParticipants:(NSArray *)participants {
    
    NSString *typingParticipants = @"";
    for (CSMessagingParticipant *participant in [messagingConversation composingParticipants]) {
        
        typingParticipants = [typingParticipants stringByAppendingString:[NSString stringWithFormat:@"%@ ", participant.displayName]];
    }
    NSLog(@"%s Conversation ID %@ participants who are typing changed: [%@]", __PRETTY_FUNCTION__, [messagingConversation conversationId], typingParticipants);
    [[NSNotificationCenter defaultCenter] postNotificationName:kParticipantTypingNotification object:typingParticipants];
}

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSMessagingServiceDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)messagingServiceAvailable:(CSMessagingService *)messagingService {
    
    NSLog(@"%s Messaging service is available", __PRETTY_FUNCTION__);
    
    [ConfigData getInstance].messagingLogin = MessagingLoginStatusLoggedIn;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshWindowNotification object:nil];
    
    if (self.conversationsWatcher == nil) {
        
        self.conversationsWatcher = [[CSDataRetrievalWatcher alloc] init];
        [self.conversationsWatcher addDelegate:self];
        [messagingService retrieveActiveConversationsWithWatcher:self.conversationsWatcher];
    }
}

- (void)messagingServiceUnavailable:(CSMessagingService *)messagingService {
    NSLog(@"%s Messaging service is unavailable", __PRETTY_FUNCTION__);
}

- (void)messagingServiceDidChangeCapabilities:(CSMessagingService *)messagingService {
    NSLog(@"%s MessagingService changed capabilities", __PRETTY_FUNCTION__);
}

- (void)messagingService:(CSMessagingService *)messagingService didChangeMessagingLimits:(CSMessagingLimits *)messagingLimits {
    NSLog(@"%s Messaging service changed messaging limits: [%@]", __PRETTY_FUNCTION__, messagingLimits);
}

- (void)messagingService:(CSMessagingService *)messagingService didChangeRoutableDomains:(NSArray *)supportedDomains {
    NSMutableString *domainsString = [NSMutableString new];
    for (NSString *domain in supportedDomains) {
        [domainsString appendFormat:@"%@ ", domain];
    }
    NSLog(@"%s Messaging service changed routable domains: %@", __PRETTY_FUNCTION__, domainsString);
}

- (void)messagingService:(CSMessagingService *)messagingService didChangeNumberOfConversationsWithUnreadContent:(NSUInteger)numberOfConversationsWithUnreadContent {
    NSLog(@"%s Messaging service changed number of conversations with unread content: %ld", __PRETTY_FUNCTION__, (long)numberOfConversationsWithUnreadContent);
}

- (void)messagingService: (CSMessagingService *)messagingService didChangeNumberOfConversationsWithUnreadContentSinceLastAccess: (NSUInteger)numberOfConversationsWithUnreadContentSinceLastAccess {
    NSLog(@"%s Messaging service changed number of conversations with unread content since last access: %ld", __PRETTY_FUNCTION__, (long)numberOfConversationsWithUnreadContentSinceLastAccess);
}

- (void)messagingServiceParticipantMatchedContactsChanged:(CSMessagingService *)messagingService {
    NSLog(@"%s Messaging service changed participant mached contacts", __PRETTY_FUNCTION__);
}

- (void)messagingService:(CSMessagingService *)messagingService didCancelRequest:(NSUInteger)requestId {
    NSLog(@"%s Messaging service cancel request: %lu", __PRETTY_FUNCTION__,  (unsigned long)requestId);
}

- (void)messagingService:(CSMessagingService *)messagingService didFailedToCancelRequest:(NSUInteger)requestId error:(NSError *)error {
    NSLog(@"%s Messaging service failed to cancel request: %lu error: %@", __PRETTY_FUNCTION__,  (unsigned long)requestId, error);
}

- (void)messagingService:(CSMessagingService *)messagingService didFailWithError:(NSError *)error {
    NSLog(@"%s Messaging service failed. Error: %@", __PRETTY_FUNCTION__, error);
}

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

#pragma mark - CSDataRetrievalWatcherDelegate

////////////////////////////////////////////////////////////////////////////////

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher didFailWithError:(NSError *)error {
    
    NSLog(@"%s data retrieval failed: %@", __PRETTY_FUNCTION__, error);
}

- (void)dataRetrievalWatcher:(CSDataRetrievalWatcher *)dataRetrievalWatcher contentsDidChange:(CSDataCollectionChangeType)changeType changedItems:(NSArray *)changedItems {
    
    if (dataRetrievalWatcher == self.conversationsWatcher) {
        
        switch(changeType) {
                
            case CSDataCollectionChangeTypeAdded:
            {
                NSLog(@"%s CONVERSATION COLLECTION UPDATED: %lu Conversations added.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
                for (CSMessagingConversation* conv in changedItems) {
                    
                    NSLog(@"%s conv: [%@]", __PRETTY_FUNCTION__, conv);
                    [self addConversationObject:conv];
                }
                break;
            }
            case CSDataCollectionChangeTypeUpdated:
            {
                NSLog(@"%s CONVERSATION COLLECTION UPDATED: %lu Conversations changed.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
                break;
            }
            case CSDataCollectionChangeTypeDeleted:
            {
                NSLog(@"%s CONVERSATION COLLECTION UPDATED: %lu Conversations deleted.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
                for (CSMessagingConversation* conv in changedItems) {
                    
                    [self removeConversationObject:conv];
                    NSLog(@"%s Conversation id: %@", __PRETTY_FUNCTION__, conv.conversationId);
                }
                break;
            }
            case CSDataCollectionChangeTypeCleared:
            {
                NSLog(@"%s CONVERSATION COLLECTION CLEARED: %lu Conversations deleted.", __PRETTY_FUNCTION__, (unsigned long)changedItems.count);
                for (CSMessagingConversation* conv in changedItems) {
                    
                    [self removeConversationObject:conv];
                }
                break;
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshConversationListNotification object:nil];
    } else if ([self.messageWatchers.allValues containsObject:dataRetrievalWatcher]) {
        
        NSString *convId = ((CSMessage*)(changedItems[0])).conversationId;
        
        switch(changeType) {
            case CSDataCollectionChangeTypeAdded:
                NSLog(@"%s CONVERSATION %@: MESSAGE COLLECTION UPDATED: %lu Messages added.", __PRETTY_FUNCTION__, convId, (unsigned long)changedItems.count);
                for (CSMessage* msg in changedItems) {
                    [self addMessageObject:msg];
                }
                break;
                
            case CSDataCollectionChangeTypeUpdated:
                NSLog(@"%s CONVERSATION %@: MESSAGE COLLECTION UPDATED: %lu Messages changed.", __PRETTY_FUNCTION__, convId, (unsigned long)changedItems.count);
                break;
                
            case CSDataCollectionChangeTypeDeleted:
                NSLog(@"%s CONVERSATION %@: MESSAGE COLLECTION UPDATED: %lu Messages deleted.", __PRETTY_FUNCTION__, convId, (unsigned long)changedItems.count);
                for (CSMessage* msg in changedItems) {
                    [self removeMessageObject:msg];
                    NSLog(@"%s Message id: %@", __PRETTY_FUNCTION__, msg.messageId);
                }
                break;
                
            case CSDataCollectionChangeTypeCleared:
                NSLog(@"%s CONVERSATION %@: MESSAGE COLLECTION CLEARED: %lu Messages deleted.", __PRETTY_FUNCTION__, convId, (unsigned long)changedItems.count);
                for (CSMessage* msg in changedItems) {
                    [self removeMessageObject:msg];
                }
                break;
        }
    } else {
        
        NSLog(@"%s Unknown CSDataRetrievalWatcher Object received", __PRETTY_FUNCTION__);
    }
}

////////////////////////////////////////////////////////////////////////////////

@end
