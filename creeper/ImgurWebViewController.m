//
//  DetailViewController.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImgurWebViewController.h"

@interface ImgurWebViewController ()

@property (nonatomic, strong) IBOutlet UIWebView *webView;

- (void)configureView;
@end

@implementation ImgurWebViewController

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
