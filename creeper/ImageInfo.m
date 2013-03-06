//
//  ImageInfo.m
//  creeper
//
//  Created by Douglas Pedley on 3/1/13.
//
//  Copyright (c) 2013 Doug Pedley. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, this
//     list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
//  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
//  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
//  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//


#import "ImageInfo.h"
#import "ImgurIOS.h"
#import "SceneCapture.h"

static NSString *creeperPrefix = @"ccf8837e-83d0-11e2-b939-f23c91aec05e"; // Note this doubles as the app store SKU

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
