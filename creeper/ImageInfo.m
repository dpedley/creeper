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
#import "iOSRedditAPI.h"
#import "SceneCapture.h"
#import "ImgurEntry.h"
#import "CreeperDataExtensions.h"

@interface ImageInfo ()

@property (nonatomic, strong) IBOutlet UITextField *titleEdit;
@property (nonatomic, strong) IBOutlet UITextField *descriptionEdit;

-(IBAction)saveAction:(id)sender;

@end

@implementation ImageInfo

#pragma mark - actions

-(NSString *)subredditFromText:(NSString *)theSub
{
	if (!theSub || [theSub length]==0)
	{
		return @"creeperapp";
	}
	
	if ([[theSub substringToIndex:3] isEqualToString:@"/r/"])
	{
		theSub = [theSub substringFromIndex:3];
		
		NSRange r = [theSub rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]];
		if (r.location != NSNotFound)
		{
			return nil;
		}
		return theSub;
	}
	
	return @"creeperapp";
}

-(void)saveNewReddit:(RedditPost *)post
{
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(saveNewReddit) withObject:nil waitUntilDone:YES];
		return;
	}
	
	// reload it here
	FeedItem *theItem = [FeedItem withEncoderID:self.item.encoderID];
	if (!theItem)
	{
		DLog(@"no item");
	}
	else
	{
		theItem.reddit = post;
		theItem.feedItemType = FeedItemType_Reddit;
		[FeedItem save];
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
	
	if (!self.titleEdit.text || [self.titleEdit.text length]==0)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Submission failed" message:@"The title is required." delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
		[alert show];
	}
	else
	{
		NSString *subreddit = [self subredditFromText:self.descriptionEdit.text];

		if (!subreddit)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Submission failed" message:@"The subreddit is invalid." delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
			[alert show];
		}
		else
		{
			__weak ImageInfo *blockSelf = self;
			[[iOSRedditAPI shared] submitLink:self.item.imgur.link toSubreddit:subreddit withTitle:self.titleEdit.text captchaVC:self submitted:^(BOOL success, RedditPost *post) {
				if (!success)
				{
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Submission failed" message:@"An unknown server error occured" delegate:self cancelButtonTitle:@"Close" otherButtonTitles:nil];
					[alert show];
				}
				else
				{
					[blockSelf saveNewReddit:post];
					[self.navigationController popToRootViewControllerAnimated:YES];
				}
			}];
		}
	}
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
