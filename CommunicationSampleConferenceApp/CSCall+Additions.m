/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "CSCall+Additions.h"
#import <objc/runtime.h>

@implementation CSCall (Additions)

- (BOOL) isActive {
    return (!self.isRemote &&
            self.state != CSCallStateIdle &&
            self.state != CSCallStateInitiating &&
            self.state != CSCallStateAlerting &&
            self.state != CSCallStateRemoteAlerting &&
            self.state != CSCallStateIgnored &&
            self.state != CSCallStateFailed &&
            self.state != CSCallStateEnded &&
            !self.isHeld);
}

- (BOOL)isFailed {
    return self.state == CSCallStateFailed;
}

- (BOOL) isHeld {
    return !self.isRemote && (self.state == CSCallStateHeld || self.state == CSCallStateHolding);
}

- (NSUUID *)UUID {
    NSUUID* uuid = objc_getAssociatedObject(self, @selector(UUID));
    if (!uuid) {
        uuid = [NSUUID UUID];
        self.UUID = uuid;
    }
    return uuid;
}

- (void)setUUID:(NSUUID *)UUID {
    objc_setAssociatedObject(self, @selector(UUID), UUID, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *)callDisplayName {
    if (self.isConference && self.conference.subject.length > 0) {
        return self.conference.subject;
    }
    else {
        return self.remoteDisplayName;
    }
}


@end
