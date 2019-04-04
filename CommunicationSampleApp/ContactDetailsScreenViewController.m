/******************************************************************************/
/*                                                                            */
/* Copyright Avaya Inc.                                                       */
/*                                                                            */
/******************************************************************************/

#import "ContactDetailsScreenViewController.h"
#import "NotificationHelper.h"

@interface ContactDetailsScreenViewController ()

@property (nonatomic, weak) NSString *firstNameBeforeEditing;
@property (nonatomic, weak) NSString *lastNameBeforeEditing;
@property (nonatomic, weak) NSString *workNumberBeforeEditing;
@property (nonatomic, weak) NSString *workEmailBeforeEditing;
@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation ContactDetailsScreenViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Check if we can edit this contact
    self.editBtnLabel.enabled = self.contact.updateCapability.allowed;
    
    self.firstName.text = [self.contact.firstName fieldValue];
    self.lastName.text = [self.contact.lastName fieldValue];
    
    // Check if contact has phone number
    if (self.contact.phoneNumbers.values.count > 0) {
        
        self.workNumber.text = [[self.contact.phoneNumbers.values firstObject] phoneNumber];
    } else {
        
        self.workNumber.text = @"";
    }
    
    // Check if contact has phone number
    if (self.contact.emailAddresses.values.count > 0) {
        
        self.workEmail.text = [(CSContactEmailAddressField *)[self.contact.emailAddresses.values firstObject] address];
    } else {
        
        self.workEmail.text = @"";
    }
    
    //Hide keyboard once clicked outside of Phone Pad
    self.tap = [[UITapGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:self.tap];
    
    [self.firstName addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.lastName addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.workNumber addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    [self.workEmail addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
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

- (IBAction)editBtn:(id)sender {
    
    if ([self.editBtnLabel.title isEqualToString:@"Edit"]) {
        
        // Change button label to 'Save'
        [self.editBtnLabel setTitle:@"Save"];
        self.editBtnLabel.enabled = NO;
        
        // Enable UITextFields for editing
        self.firstName.enabled = YES;
        self.lastName.enabled = YES;
        self.workNumber.enabled = YES;
        self.workEmail.enabled = YES;
        
        self.firstNameBeforeEditing = self.firstName.text;
        self.lastNameBeforeEditing = self.lastName.text;
        self.workNumberBeforeEditing = self.workNumber.text;
        self.workEmailBeforeEditing = self.workEmail.text;
        
    } else if ([self.editBtnLabel.title isEqualToString:@"Save"]) {
        
        CSContactService *contactService = nil;
        for (CSUser *user in [SDKManager getInstance].users) {
            if (user.contactService) {
                contactService = user.contactService;
                break;
            }
        }
        
        CSEditableContact *editedContact = [contactService createEditableContactFromContact:self.contact];
        
        editedContact.firstName.fieldValue = self.firstName.text;
        editedContact.lastName.fieldValue = self.lastName.text;
        
        CSEditableContactEmailAddressField *emailField = [CSEditableContactEmailAddressField new];
        emailField.emailAddressType = CSContactEmailAddressTypeWork;
        emailField.address = self.workEmail.text;
        
        // Check if work-email was updated in edit operation
        if(!self.contact.emailAddresses.values.count){
            [editedContact.emailAddresses addItem:emailField];
            
        }else{
        for (CSContactEmailAddressField *email in self.contact.emailAddresses.values) {
            
            if (email.type == CSContactEmailAddressTypeWork) {
                
                if (![email.address isEqualToString:self.workEmail.text]) {
                    
                    [editedContact.emailAddresses removeItem:(CSEditableContactEmailAddressField *)email];
                    [editedContact.emailAddresses addItem:emailField];
                    break;
                }
            }
         }
        }
        
        // Check if work-phone was updated in edit operation
        for (CSContactPhoneField *phone in self.contact.phoneNumbers.values) {
            
            if (phone.type == CSContactPhoneNumberTypeWork) {
                
                if (![phone.phoneNumber isEqualToString:self.workNumber.text]) {
                    
                    CSEditableContactPhoneField *phoneField = [CSEditableContactPhoneField new];
                    phoneField.phoneNumber = self.workNumber.text;
                    phoneField.defaultPhoneNumber = YES;
                    phoneField.phoneNumberType = CSContactPhoneNumberTypeWork;
                    editedContact.phoneNumbers.values = @[phoneField];
                    break;
                }
            }
        }
        
        
        [contactService updateContact:editedContact completionHandler:^(CSContact *contact, NSError *error) {
            
            if (error) {
                
                NSLog(@"%s Error while updating contact. Error code [%ld] - %@", __PRETTY_FUNCTION__, (long)error.code, error.localizedDescription);
                [NotificationHelper displayMessageToUser: [NSString stringWithFormat:@"Error while updating contact. Error code [%ld] - %@", (long)error.code, error.localizedDescription] TAG:__PRETTY_FUNCTION__];
            } else {
                
                NSLog(@"%s Contact updated successfully, contact [%@]", __PRETTY_FUNCTION__, contact);
                [[NSNotificationCenter defaultCenter] postNotificationName:kRefreshContactListNotification object:nil];
            }
        }];
        
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)textFieldDidChange :(UITextField *)theTextField{
    
    // Enable Save button only contact was edited
    if ([self.firstName.text isEqualToString:self.firstNameBeforeEditing] &&
        [self.lastName.text isEqualToString:self.lastNameBeforeEditing] &&
        [self.workNumber.text isEqualToString:self.workNumberBeforeEditing] &&
        [self.workEmail.text isEqualToString:self.workEmailBeforeEditing]) {
        
        self.editBtnLabel.enabled = NO;
    } else {
        
        self.editBtnLabel.enabled = YES;
    }
}

@end
