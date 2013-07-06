//
//  RedditPostCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/4/13.
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

#import "RedditPostCell.h"

#import "ImgurEntry.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "NSDate+TimeAgo.h"
#import "GifCreationManager.h"
#import "iOSRedditAPI.h"
#import "SceneCapture.h"

typedef enum
{
	ImgurInfoAlertOption_Cancel = 0,
	ImgurInfoAlertOption_ImgurID,
	ImgurInfoAlertOption_ImgurLink,
} ImgurInfoAlertOption;

static int ImgurInfoAlert = 100;

@interface RedditPostCell ()

@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UILabel *karmaLabel;
@property (nonatomic, strong) IBOutlet UIButton *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;


-(IBAction)imageInfoAction:(id)sender;

@end

@implementation RedditPostCell

- (void) prepareForReuse
{
	[super prepareForReuse];
	[self.actionButton setHidden:NO];
	[self.infoLabel setHidden:YES];
	self.reddit = nil;
	self.infoLabel.text = @"";
	self.karmaLabel.text = @"";
	self.timestampLabel.text = @"";
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	self.karmaLabel.text = @"";
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

/*
-(NSString *)imgurIDSafe
{
	NSString *imgurID = nil;
	if (self.encoderID)
	{
		FeedItem *item = [FeedItem withEncoderID:self.encoderID];
		imgurID = item.imgur.imgurID;
	}
	else if (self.redditEntry)
	{
		imgurID = self.redditEntry.imgurID;
	}
	return imgurID;
}

-(NSString *)imgurSafe
{
	NSString *imgur = nil;
	if (self.encoderID)
	{
		FeedItem *item = [FeedItem withEncoderID:self.encoderID];
		imgur = item.imgur.link;
	}
	else if (self.reddit)
	{
		imgur = self.reddit.imgur;
	}
	return imgur;
}
*/

-(void)startPreviewAnimation
{
	if (!self.animationLoaded)
	{
		NSArray *cachedFrames = [self.reddit cachedAnimationFrames];
		if (cachedFrames)
		{
			[self.preview setAnimationImages:cachedFrames];
			[self.preview setAnimationDuration:[cachedFrames count] * SceneCaptureFrameInterval];
			self.animationLoaded = YES;
		}
	}
	[super startPreviewAnimation];
}

-(void)configureWithItem:(FeedItem *)item detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	[super configureWithItem:item detailLevel:level];
	if (!self.reddit) // This must be our first load.
	{
		self.reddit = item.reddit;
		[self.actionButton setHidden:NO];
		[self.infoLabel setHidden:YES];
		[self configureWithReddit:item.reddit detailLevel:level];
		
		__weak RedditPostCell *blockSelf = self;
		[[iOSRedditAPI shared] loadCurrentDataForRedditPostID:item.reddit.redditID completion:^(NSDictionary *postDictionary, BOOL cached) {
			
			if (!cached)
			{
				[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
					RedditPost *reddit = [RedditPost withDictionary:postDictionary inContext:localContext];
					[blockSelf.karmaLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%@", reddit.score] waitUntilDone:NO];
				} completion:^(BOOL success, NSError *error) {
					DLog(@"the post: %@", postDictionary);
				}];
			}
			else
			{
				DLog(@"the cached post: %@", postDictionary);
			}
		}];
	}

	// Set the timestamp
	self.timestampLabel.text = [item.timestamp timeAgo];
}

-(void)configureWithReddit:(RedditPost *)rp detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	[super configureWithReddit:rp detailLevel:level];
	
	[self.actionButton setHidden:NO];
	[self.infoLabel setHidden:YES];
	
	self.reddit = rp;
	
	self.karmaLabel.text = [NSString stringWithFormat:@"%@", rp.score];
	
	self.timestampLabel.text = [rp.created timeAgo];
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return (item.feedItemType==FeedItemType_Reddit);
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag==ImgurInfoAlert)
	{
		switch (buttonIndex)
		{
			case ImgurInfoAlertOption_Cancel:
			{
				// No action needed.
			}
				break;
				
			case ImgurInfoAlertOption_ImgurID:
			{
				if (self.reddit.imgurID)
				{
					UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
					pasteboard.string = self.reddit.imgurID;
				}
			}
				break;
				
			case ImgurInfoAlertOption_ImgurLink:
			{
				if (self.reddit.imgurLink)
				{
					UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
					pasteboard.string = self.reddit.imgurLink;
				}
			}
				break;
								
			default:
				break;
		}
	}
	[alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
}

-(IBAction)imageInfoAction:(id)sender
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Imgur Info"
													message:self.reddit.imgurID
												   delegate:self
										  cancelButtonTitle:@"Close"
										  otherButtonTitles:@"Copy Image ID", @"Copy link", 
						  nil];
	
	alert.tag = ImgurInfoAlert;
	[alert show];
}

@end
