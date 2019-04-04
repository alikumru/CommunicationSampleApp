/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "CallLogViewController.h"
#import "SDKManager.h"

@interface CallLogViewController ()

@end

@implementation CallLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    CSCallLogService *callLogService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        
        if (user.callLogService) {
            
            callLogService = user.callLogService;
            break;
        }
    }
    
    NSLog(@"%s Number of Call Logs: [%lu]", __PRETTY_FUNCTION__, (unsigned long)callLogService.callLogs.count);
    return callLogService.callLogs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CSCallLogService *callLogService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        
        if (user.callLogService) {
            
            callLogService = user.callLogService;
            break;
        }
    }
    
    NSArray *logItems = callLogService.callLogs;
    
    // Populate call log in reverse order i.e. newest entries first
    CSCallLogItem *item = logItems[logItems.count - (indexPath.row + 1)];
    
    static NSString *tableIdentifier = @"CallLogEntry";
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tableIdentifier];
    
    // Call Mode
    NSString *mode = nil;
    switch (item.callLogActionType) {
        case CSCallLogActionTypeUndefined:
            mode = @"Undefined";
            break;
        case CSCallLogActionTypeMissed:
            mode = @"Missed";
            break;
        case CSCallLogActionTypeRedirected:
            mode = @"Redirected";
            break;
        case CSCallLogActionTypeAnswered:
            mode = @"Answered";
            break;
        case CSCallLogActionTypeOutgoing:
            mode = @"Outgoing";
            break;
        case CSCallLogActionTypeTransferred:
            mode = @"Transferred";
            break;
        case CSCallLogActionTypeIncoming:
            mode = @"Incoming";
            break;
        default:
            break;
    }
    
    // (Call Duration)
    NSInteger timeInterval = (NSInteger)item.durationInSeconds;
    NSInteger ss = timeInterval % 60;
    NSInteger mm = (timeInterval / 60) % 60;
    NSInteger hh = timeInterval / 3600;
    
    NSString *remoteParty = nil;
    
    if ([item.remoteParticipants.firstObject matchingContact]) {
        
        remoteParty = [[[item.remoteParticipants.firstObject matchingContact] displayName] fieldValue];
    }
    
    // Get name of remote participant
    remoteParty = [NSString stringWithFormat:@"%@", [item.remoteParticipants.firstObject displayName]];
    
    // Check if remote participant name is available
    if ([remoteParty length] == 0) {
        
        remoteParty = @"Unknown";
    }
    
    NSString *callTime = @"";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [NSLocale currentLocale];
    
    [dateFormatter setDateStyle:/*NSDateFormatterNoStyle*/NSDateFormatterShortStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    callTime = [dateFormatter stringFromDate:item.startTime];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@ [%@]", remoteParty, item.remoteNumber];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%11@    %25@    %@", mode, callTime, [NSString stringWithFormat:@"%0.2ld:%0.2ld:%0.2ld", (long)hh, (long)mm, (long)ss]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    int selectedRow = (int)indexPath.row;
    NSLog(@"%s selected row: [%d]", __PRETTY_FUNCTION__, selectedRow + 1);
}
@end
