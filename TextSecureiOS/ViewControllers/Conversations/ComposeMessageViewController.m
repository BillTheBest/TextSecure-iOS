//
//  ComposeMessageViewController.m
//  TextSecureiOS
//
//  Created by Frederic Jacobs on 10/30/13.
//  Copyright (c) 2013 Open Whisper Systems. All rights reserved.
//

#import "ComposeMessageViewController.h"
#import "TSMessagesManager.h"
#import "TSContactManager.h"
#import "TSContact.h"
#import "TSMessagesDatabase.h"
#import "TSMessage.h"
#import "TSThread.h"
#import "TSKeyManager.h"
#import "TSAttachment.h"
#import "TSAttachmentManager.h"
#import "Cryptography.h"
#import "FilePath.h"

@interface ComposeMessageViewController ()
@property (nonatomic, retain) NSArray *contacts;
@property (nonatomic, retain) NSArray *messages;
@end

@implementation ComposeMessageViewController

- (id) initWithConversation:(TSThread*)thread {
    
    self = [super initWithNibName:nil bundle:nil];
    
    self.thread = thread;
    self.delegate = self;
    
    [self setupThread];
    
    return self;
}

-(void) setupThread  {
    self.contact = [self.thread.participants objectAtIndex:0];
    self.title = [self.contact name];
    [self.tableView setContentOffset:CGPointMake(0, CGFLOAT_MAX)]; //scrolls to bottom
}

- (void) dismissVC {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [TSMessagesDatabase getMessagesOnThread:self.thread withCompletion:^(NSArray* messages) {
        self.messages = messages;
        [self.tableView reloadData];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadModel:) name:TSDatabaseDidUpdateNotification object:nil];
    self.delegate = self;
    self.dataSource = self;
    [self.view setBackgroundColor:[UIColor whiteColor]];
    self.tableView.frame = CGRectMake(0, 0, self.tableView.frame.size.width, self.view.frame.size.height - 44);
}

#pragma mark - Table view data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.messages count];
}

#pragma mark - Messages view delegate

- (JSMessageInputViewStyle)inputViewStyle{
    return JSMessageInputViewStyleFlat;
}

- (JSMessagesViewSubtitlePolicy)subtitlePolicy{
    return JSMessagesViewSubtitlePolicyNone;
}

- (UIImageView *)avatarImageViewForRowAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

- (NSString *)subtitleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return nil;
}

- (void)didSendText:(NSString *)text {
    
    TSMessage *message = [TSMessage messageWithContent:text sender:[TSKeyManager getUsernameToken] recipient:self.contact.registeredID date:[NSDate date] attachment:self.attachment];
    
    //    if(message.attachment.attachmentType!=TSAttachmentEmpty) {
    //        // this is asynchronous so message will only be send by messages manager when it succeeds
    //        [TSAttachmentManager uploadAttachment:message];
    //    }
    
    [[TSMessagesManager sharedManager] sendMessage:message onThread:self.thread];
    
    [self finishSend];
}

- (void)photoPressed:(UIButton *)sender {
    UIActionSheet* actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take Photo or Video",@"Choose Existing", nil];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    UIImagePickerController *imagePicker =  [[UIImagePickerController alloc] init];
    imagePicker.delegate = self;
    
    imagePicker.mediaTypes =  @[(NSString *) kUTTypeImage, (NSString *) kUTTypeMovie];
    
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

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    
    NSData* attachmentData;
    TSAttachmentType  attachmentType = TSAttachmentEmpty;
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        attachmentData= UIImagePNGRepresentation(image);
        attachmentType = TSAttachmentPhoto;
    }
    else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie]) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        
        attachmentData=[NSData dataWithContentsOfURL:videoURL];
        attachmentType = TSAttachmentVideo;
    }
    // encryption attachment data, write to file, and initialize the attachment
    NSData *randomEncryptionKey;
    NSData *encryptedData = [Cryptography encryptAttachment:attachmentData withRandomKey:&randomEncryptionKey];
    NSString* filename = [[Cryptography truncatedHMAC:encryptedData withHMACKey:randomEncryptionKey truncation:10] base64EncodedStringWithOptions:0];
    NSString* writeToFile = [FilePath pathInDocumentsDirectory:filename];
    [encryptedData writeToFile:writeToFile atomically:YES];
    self.attachment = [[TSAttachment alloc] initWithAttachmentDataPath:writeToFile withType:attachmentType withDecryptionKey:randomEncryptionKey];
    //size of button
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) reloadModel:(NSNotification*)notification {
    [self.tableView reloadData];
    NSLog(@"user info %@",[notification userInfo]);
    if([[[notification userInfo] objectForKey:@"messageType"] isEqualToString:@"send"]) {
        [JSMessageSoundEffect playMessageSentSound];
    }
    else {
        [JSMessageSoundEffect playMessageReceivedSound];
    }
}

- (UIImageView *)bubbleImageViewWithType:(JSBubbleMessageType)type
                       forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (type == JSBubbleMessageTypeIncoming) {
        return [JSBubbleImageViewFactory bubbleImageViewForType:type
                                                          color:[UIColor js_bubbleLightGrayColor]];
    } else{
        
        return [JSBubbleImageViewFactory bubbleImageViewForType:type
                                                          color:[UIColor js_bubbleBlueColor]];
    }
}

- (JSBubbleMessageType)messageTypeForRowAtIndexPath:(NSIndexPath *)indexPath {
    if([[[self.messages objectAtIndex:indexPath.row] senderId] isEqualToString:[TSKeyManager getUsernameToken]]) {
        return JSBubbleMessageTypeOutgoing;
    }
    else {
        return  JSBubbleMessageTypeIncoming;
    }
}

- (JSMessagesViewTimestampPolicy)timestampPolicy {
    return JSMessagesViewTimestampPolicyEveryThree;
}

- (JSMessagesViewAvatarPolicy)avatarPolicy {
    return JSMessagesViewAvatarPolicyNone;
}

#pragma mark - Messages view data source
- (BOOL) shouldHaveThumbnailForRowAtIndexPath:(NSIndexPath*)indexPath {
    TSAttachment *attachment = [[self.messages objectAtIndex:indexPath.row] attachment];
    return attachment.attachmentType != TSAttachmentEmpty;
}
- (UIImage *)thumbnailForRowAtIndexPath:(NSIndexPath *)indexPath {
    TSAttachment *attachment = [[self.messages objectAtIndex:indexPath.row] attachment];
    return [attachment getThumbnailOfSize:100];
}

- (NSString *)textForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self.messages objectAtIndex:indexPath.row] content];
}

- (NSDate *)timestampForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [(TSMessage*)[self.messages objectAtIndex:indexPath.row] timestamp];
}

- (UIImage *)avatarImageForIncomingMessage {
    return nil;
}

- (UIImage *)avatarImageForOutgoingMessage {
    return nil;
}

@end