//
//  ImgurSubmit.m
//  creeper
//
//  Created by Douglas Pedley on 4/10/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImgurSubmit.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "ImgurIOS.h"
#import "GifCreationManager.h"

@interface ImgurSubmit ()

@property (nonatomic, strong) IBOutlet UITextField *titleEdit;
@property (nonatomic, strong) IBOutlet UITextField *descriptionEdit;

-(IBAction)saveAction:(id)sender;

@end

@implementation ImgurSubmit

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	[self.titleEdit becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

+(NSString *)uniqueName
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	CFStringRef uuidString = CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	NSString *uName = [NSString stringWithFormat:@"%@_%@", creeperPrefix, uuidString];
	CFRelease(uuidString);
	return uName;
}

- (void)uploadFailed
{
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(uploadFailed) withObject:nil waitUntilDone:NO];
		return;
	}
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Sorry" message:@"The upload failed, please try again." delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
	[alert show];
	
	[MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
		FeedItem *uploadingItem = [FeedItem withEncoderID:self.item.encoderID inContext:localContext];
		uploadingItem.feedItemType = FeedItemType_Encoded;
	}];
}

-(void)uploadBackground
{
	NSString *dataPath = [GifCreationManager storageLocationForEncoderID:self.item.encoderID imageIndex:0];
	NSData *gifData = [NSData dataWithContentsOfFile:dataPath];
	if (gifData)
	{
		__weak ImgurSubmit *blockSelf = self;
		__block NSString *newName = [ImgurSubmit uniqueName];
		__block NSString *blockEncoderID = [[NSString alloc] initWithString:self.item.encoderID];
		[ImgurIOS uploadImageData:gifData name:newName title:self.titleEdit.text description:self.descriptionEdit.text
				   uploadComplete:^(BOOL success, ImgurEntry *imgur) {
					   if (success)
					   {
						   FeedItem *item = [FeedItem withEncoderID:blockEncoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
						   if (item)
						   {
							   [SVProgressHUD dismiss];
							   [item attachToImgur:imgur];
							   [self.navigationController popToRootViewControllerAnimated:YES];
						   }
						   else
						   {
							   // we must have been deleted
							   // let's assume we should remove the online version too.
							   [ImgurIOS deleteImageWithHashToken:imgur.deletehash deleteComplete:^(BOOL success) {
								   [SVProgressHUD dismiss];
								   [self.navigationController popToRootViewControllerAnimated:YES];
							   }];
							   
							   [MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
								   ImgurEntry *localEntry = [ImgurEntry findFirstByAttribute:@"imgurID" withValue:imgur.imgurID inContext:localContext];
								   [localEntry deleteInContext:localContext];
							   } completion:^(BOOL success, NSError *error) {
								   DLog(@"Image upload success, but local removed.");
							   }];
						   }
					   }
					   else
					   {
						   [SVProgressHUD dismiss];
						   [blockSelf uploadFailed];
					   }
				   }];
	}
}

-(IBAction)saveAction:(id)sender
{
	if ([self.titleEdit isFirstResponder])
	{
		[self.titleEdit resignFirstResponder];
	}
	
	if ([self.descriptionEdit isFirstResponder])
	{
		[self.descriptionEdit resignFirstResponder];
	}
	
	[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
		FeedItem *uploadingItem = [FeedItem withEncoderID:self.item.encoderID inContext:localContext];
		uploadingItem.feedItemType = FeedItemType_Uploading;
	} completion:^(BOOL success, NSError *error) {
		[self performSelectorInBackground:@selector(uploadBackground) withObject:nil];
	}];
	
	[SVProgressHUD showWithStatus:@"Uploading..." maskType:SVProgressHUDMaskTypeGradient];
}

@end
