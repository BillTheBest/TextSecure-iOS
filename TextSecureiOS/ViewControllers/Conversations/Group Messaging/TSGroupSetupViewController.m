//
//  TSGroupSetupViewController.m
//  TextSecureiOS
//
//  Created by Christine Corbett Moran on 3/8/14.
//  Copyright (c) 2014 Open Whisper Systems. All rights reserved.
//

#import "TSGroupSetupViewController.h"
#import "TSMessageViewController.h"
#import "TextSecureViewController.h"

@interface TSGroupSetupViewController ()

@end

@implementation TSGroupSetupViewController

-(id) initWithCoder:(NSCoder *)aDecoder {
    if(self = [super initWithCoder:aDecoder]) {
        self.group = [[TSGroup alloc] init];
    }
    return self;

}
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    self.nextButton.enabled = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction) setGroupPhotoPressed:(UIButton *)sender {
    UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take Photo or Video",@"Choose Existing", nil];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    UIImagePickerController *imagePicker =  [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    
    imagePicker.mediaTypes =  @[(NSString *) kUTTypeImage];
    
    imagePicker.allowsEditing = NO;
    
    switch (buttonIndex) {
        case 0:
            imagePicker.sourceType =  UIImagePickerControllerSourceTypeCamera;
            break;
        case 1:
            imagePicker.sourceType =  UIImagePickerControllerSourceTypePhotoLibrary;
            break;
        case 2:
            // cancel
            return;
        default:
            break;
    }
    [self presentViewController:imagePicker animated:YES completion:nil];
    
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if([[textField.text stringByReplacingCharactersInRange:range withString:string] length]>0) {
        self.nextButton.enabled = YES;
        
    }
    else {
        self.nextButton.enabled = NO;

    }
    return YES;
}


-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [self.groupPhoto setImage:image forState:UIControlStateNormal];
    self.groupPhoto.layer.cornerRadius =self.groupPhoto.bounds.size.width/1.6;
    self.groupPhoto.layer.masksToBounds = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}


-(IBAction)createNonBroadcastGroup:(id)sender {
    self.group.groupName = self.groupName.text;
    self.group.groupImage = self.groupPhoto.imageView.image;
    self.group.isNonBroadcastGroup = YES;
    [self createGroup];
}



-(IBAction)createGroup {
    [self performSegueWithIdentifier:@"GroupComposeMessageSegue" sender:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.destinationViewController isKindOfClass:[TSMessageViewController class]]) {
        TSMessageViewController *vc = segue.destinationViewController;
        vc.group = self.group;
    }
}

@end
