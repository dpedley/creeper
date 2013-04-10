//
//  DetailViewController.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
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

#import "ImgurWebViewController.h"
#import "ImgurIOS.h"
#import "SHK.h"
#import "NSDate+TimeAgo.h"
#import "iOSRedditAPI.h"
#import "SVProgressHUD.h"
#import "FeedItem.h"
#import "RedditPost.h"
#import "CreeperDataExtensions.h"

typedef enum
{
	ImageShareAlertOption_Cancel = 0,
	ImageShareAlertOption_Browser,
	ImageShareAlertOption_CopyLink,
	ImageShareAlertOption_ShareLink
} ImageShareAlertOption;

static int ImgurWebView_ShareAlert = 100;

@interface ImgurWebViewController ()

@property (nonatomic, strong) IBOutlet UIWebView *webView;

-(IBAction)shareAction:(id)sender;

- (void)configureView;
@end

@implementation ImgurWebViewController

-(void)shareItem:(SHKItem *)item
{
	// Get the ShareKit action sheet
	SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
	
	// ShareKit detects top view controller (the one intended to present ShareKit UI) automatically,
	// but sometimes it may not find one. To be safe, set it explicitly
	[SHK setRootViewController:self];
	
	// Display the action sheet
	[actionSheet showFromToolbar:self.navigationController.toolbar];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag==ImgurWebView_ShareAlert)
	{
		switch (buttonIndex)
		{
			case ImageShareAlertOption_Cancel:
			{
				// No action needed.
			}
				break;
				
			case ImageShareAlertOption_Browser:
			{
				[[UIApplication sharedApplication] openURL:self.item.reddit.mobileURL];
			}
				break;
				
			case ImageShareAlertOption_CopyLink:
			{
				UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
				pasteboard.string = self.item.reddit.redditURL;
			}
				break;
				
			case ImageShareAlertOption_ShareLink:
			{
				NSURL *url = [NSURL URLWithString: self.item.reddit.redditURL];
				SHKItem *item = [SHKItem URL:url title:@"Creeper animation" contentType:SHKURLContentTypeWebpage];
				[self shareItem:item];
			}
				break;
				
			default:
				break;
		}	
	}
	[alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
}

-(IBAction)shareAction:(id)sender
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Utilities"
													message:@"Please choose an option below"
												   delegate:self
										  cancelButtonTitle:@"Cancel"
										  otherButtonTitles:
			@"Open Browser", @"Copy Link", @"Share Link", nil];
	alert.tag = ImgurWebView_ShareAlert;
	[alert show];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[SVProgressHUD dismiss];
}

- (void)configureView
{
    // Update the user interface for the detail item.

	[SVProgressHUD showWithStatus:@"Loading Post"];
	[self.webView loadRequest:[NSURLRequest requestWithURL:self.item.reddit.mobileURL]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	[self configureView];
}

-(void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[SVProgressHUD dismiss];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
