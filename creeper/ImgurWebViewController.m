//
//  DetailViewController.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImgurWebViewController.h"
#import "ImgurIOS.h"
#import "SHK.h"

@interface ImgurWebViewController ()

@property (nonatomic, strong) IBOutlet UIWebView *webView;

-(IBAction)shareAction:(id)sender;

- (void)configureView;
@end

@implementation ImgurWebViewController

-(IBAction)shareAction:(id)sender
{
	// Create the item to share (in this example, a url)
//	NSURL *url = [NSURL URLWithString:self.imgur.link];
	
//	SHKItem *item = [SHKItem URL:url title:@"Creeper Animation" contentType:SHKURLContentTypeWebpage];
	SHKItem *item = [SHKItem file:self.imgur.imageData filename:@"creeper.gif" mimeType:@"image/gif" title:@"Creeper animation"];
	
	// Get the ShareKit action sheet
	SHKActionSheet *actionSheet = [SHKActionSheet actionSheetForItem:item];
	
	// ShareKit detects top view controller (the one intended to present ShareKit UI) automatically,
	// but sometimes it may not find one. To be safe, set it explicitly
	[SHK setRootViewController:self];
	
	// Display the action sheet
	[actionSheet showFromToolbar:self.navigationController.toolbar];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	[SVProgressHUD dismiss];
}

- (void)configureView
{
    // Update the user interface for the detail item.

	[SVProgressHUD showWithStatus:@"Loading Imgur"];
	if (self.imgur)
	{
		NSString *webViewLink = [NSString stringWithFormat:@"http://imgur.com/%@", self.imgur.imgurID];
		NSURL *url = [NSURL URLWithString:webViewLink];
		NSLog(@"Opening URL: %@", url);
		[self.webView loadRequest:[[NSURLRequest alloc]initWithURL:url]];
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
