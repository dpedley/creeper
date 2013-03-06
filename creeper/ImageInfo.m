//
//  ImageInfo.m
//  creeper
//
//  Created by Douglas Pedley on 3/1/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImageInfo.h"
#import "ImgurIOS.h"
#import "SceneCapture.h"

static NSString *creeperPrefix = @"ccf8837e-83d0-11e2-b939-f23c91aec05e"; // Note this doubles as the app store SKU

typedef enum
{
	eInputCellsName = 0,
	eInputCellsTitle,
	eInputCellsDescription,
} eInputCells;

@interface ImageInfo ()

@property (nonatomic, strong) IBOutlet UITextField *titleEdit;
@property (nonatomic, strong) IBOutlet UITextField *descriptionEdit;

-(IBAction)saveAction:(id)sender;

@end

@implementation ImageInfo

#pragma mark - actions

-(NSString *)uniqueName
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	CFStringRef uuidString = CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	return [NSString stringWithFormat:@"%@_%@", creeperPrefix, uuidString];
}

-(void)saveWhenReady
{
	int workload = [self.cc encodingWorkload];
	int frameCount = self.cc.frameCount;
	if (workload>0)
	{
		[SVProgressHUD showProgress:1.00 - ((double)frameCount / (double) workload)
							 status: [NSString stringWithFormat:@"Encoding %d of %d", frameCount - workload, frameCount]
						   maskType:SVProgressHUDMaskTypeGradient];
		[self performSelector:@selector(saveWhenReady) withObject:nil afterDelay:0.1];
		return;
	}
	
	[self.cc completeEncoding];
	[SVProgressHUD showWithStatus:@"Uploading animation" maskType:SVProgressHUDMaskTypeGradient];
	[ImgurIOS uploadImageData:self.cc.imageData
						 name:[self uniqueName]
						title:self.titleEdit.text
				  description:self.descriptionEdit.text
			   uploadComplete:^(BOOL success)
	 {
		 [SVProgressHUD dismiss];
		 if (!success)
		 {
			 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Upload failed" message:@"An unknown server error occured" delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
			 [alert show];
		 }
		 else
		 {
			 [self.navigationController popToRootViewControllerAnimated:YES];
		 }
	 }
	];
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
	
	[self saveWhenReady];
}


#pragma mark - object lifecycle

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
	{
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

@end
