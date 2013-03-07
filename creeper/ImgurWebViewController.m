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

static int ImgurWebView_ShareAlert = 100;

@interface ImgurWebViewController ()

@property (nonatomic, strong) IBOutlet UIWebView *webView;

-(IBAction)shareAction:(id)sender;

- (void)configureView;
@end

@implementation ImgurWebViewController

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag==ImgurWebView_ShareAlert)
	{
		if (buttonIndex==1)
		{
			NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://i.imgur.com/%@", self.imgur.imgurID]];
			[[UIApplication sharedApplication] openURL:url];
		}
		else if (buttonIndex==2)
		{
			UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
			pasteboard.string = self.imgur.link;
		}
		else if (buttonIndex!=0)
		{
			// Create the item to share (in this example, a url)
			SHKItem *item = nil;
			
			if (buttonIndex==3)
			{
				item = [SHKItem file:self.imgur.imageData filename:@"creeper.gif" mimeType:@"image/gif" title:@"Creeper animation"];
			}
			else
			{
				NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://i.imgur.com/%@", self.imgur.imgurID]];
				item = [SHKItem URL:url title:@"Creeper animation" contentType:SHKURLContentTypeWebpage];
			}
			// Get the ShareKit action sheet
			SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
			
			// ShareKit detects top view controller (the one intended to present ShareKit UI) automatically,
			// but sometimes it may not find one. To be safe, set it explicitly
			[SHK setRootViewController:self];
			
			// Display the action sheet
			[actionSheet showFromToolbar:self.navigationController.toolbar];
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
										  otherButtonTitles:@"Open Browser", @"Copy Link", @"Share Original", @"Share Link", nil];
	alert.tag = ImgurWebView_ShareAlert;
	[alert show];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
//	NSString *html = [webView stringByEvaluatingJavaScriptFromString:
//					  @"document.body.innerHTML"];
//	DLog(@"Mobile imgur:\n\n%@\n\n", html);
	[SVProgressHUD dismiss];
}

-(NSString *)template:(NSString *)htmlTemplate parseWithImgurEntry:(ImgurEntry *)entryTokens
{
	BOOL parsing = YES;
	
	NSMutableString *pageParsed = [htmlTemplate mutableCopy];
	while (parsing)
	{
		NSRange startFound = [pageParsed rangeOfString:@"{~"];
		
		if (startFound.location!=NSNotFound)
		{
			int startFoundOffset = startFound.location + startFound.length;
			NSRange atLeastOneCharFurther = NSMakeRange(startFoundOffset + 1,
														[pageParsed length] - (startFoundOffset + 1) );
			
			NSRange endFound = [pageParsed rangeOfString:@"~}" options:0 range:atLeastOneCharFurther];
			
			if (endFound.location!=NSNotFound)
			{
				NSRange tokenRange = NSMakeRange(startFoundOffset, endFound.location - startFoundOffset);
				NSString *token = [pageParsed substringWithRange:tokenRange];
				token = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				
				NSRange replaceRange = NSMakeRange(startFound.location, (endFound.location + endFound.length) - startFound.location);
				NSString *replaceString = [NSString stringWithFormat:@"debug_%@", token];
				
				if ([token isEqualToString:@"imgurID"])
				{
					replaceString = entryTokens.imgurID;
				}
				else if ([token isEqualToString:@"title"])
				{
					replaceString = entryTokens.imgTitle;
				}
				else if ([token isEqualToString:@"timeAgo"])
				{
					NSTimeInterval epochTime = [entryTokens.timestamp doubleValue];
					NSDate *creationDate = [NSDate dateWithTimeIntervalSince1970:epochTime];
					replaceString = [creationDate timeAgo];
				}
				
				[pageParsed replaceCharactersInRange:replaceRange withString:replaceString];
			}
			else
			{
				NSLog(@"Start {~ without an end ~} is a bad thing... ");
				parsing = NO;
			}
		}
		else
		{
			DLog(@"Done parsing");
			parsing = NO;
		}
	}
	
	return pageParsed;
}

- (void)configureView
{
    // Update the user interface for the detail item.

	[SVProgressHUD showWithStatus:@"Loading Imgur"];
	if (self.imgur)
	{
		NSString *htmlTemplate = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ImgurViewTemplate" withExtension:@"html"] encoding:NSASCIIStringEncoding error:nil];

		if (!htmlTemplate)
		{
			DLog(@"No template");
			[self.webView loadData:self.imgur.imageData MIMEType:@"image/gif" textEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://i.imgur.com"]];
			return;
		}
		
		NSString *pageParsed = [self template:htmlTemplate parseWithImgurEntry:self.imgur];
		
		DLog(@"Opening Data: %@", pageParsed);
		NSData *pageData = [pageParsed dataUsingEncoding:NSUTF8StringEncoding];
		
		[self.webView loadData:pageData MIMEType:@"text/html" textEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://i.imgur.com"]];
	}
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
