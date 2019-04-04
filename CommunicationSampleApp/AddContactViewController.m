/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "AddContactViewController.h"
#import "SDKManager.h"
#import "NotificationHelper.h"

@interface AddContactViewController ()

@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation AddContactViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
}

- (void)dealloc {
    
    [self.view removeGestureRecognizer:self.tap];
}

- (void)dismissKeyboard {
    
    [self.firstName resignFirstResponder];
    [self.lastName resignFirstResponder];
    [self.workNumber resignFirstResponder];
    [self.workEmail resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)saveBtn:(id)sender {
    
    CSContactService *contactService = nil;
    for (CSUser *user in [SDKManager getInstance].users) {
        
        if (user.contactService) {
            
            contactService = user.contactService;
            break;
        }
    }
    
    CSEditableContact *contact = [contactService createEditableContact];
    
    contact.firstName.fieldValue = self.firstName.text;
    contact.lastName.fieldValue = self.lastName.text;
    
    CSEditableContactEmailAddressField *emailField = [CSEditableContactEmailAddressField new];
    emailField.emailAddressType = CSContactEmailAddressTypeWork;
    emailField.address = self.workEmail.text;
    [contact.emailAddresses addItem:emailField];
    
    CSEditableContactPhoneField *phoneField = [CSEditableContactPhoneField new];
    phoneField.phoneNumber = self.workNumber.text;
    phoneField.defaultPhoneNumber = YES;
    phoneField.phoneNumberType = CSContactPhoneNumberTypeWork;
    [contact.phoneNumbers setValues:@[phoneField]];
    
    [contactService addContact:contact completionHandler:^(CSContact *contact, BOOL contactWasMerged, NSError *error) {
        
        if (error) {
            
            NSLog(@"%s Error while adding contact. Error code [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
            [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while adding contact. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG:__PRETTY_FUNCTION__];
        } else {
            
            NSLog(@"%s Contact added successfully, contact [%@]", __PRETTY_FUNCTION__, contact);
            [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
        }
    }];
    [self.navigationController popViewControllerAnimated:YES];
}
@end
