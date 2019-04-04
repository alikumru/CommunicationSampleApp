/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "VideoView.h"
#import <AvayaClientMedia/CSVideoRendererIOS.h>

@implementation VideoView

+ (Class) layerClass {
    return [CSVideoRendererIOS class];
}
@end
