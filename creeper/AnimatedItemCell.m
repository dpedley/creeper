//
//  AnimatedItemCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/9/13.
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

#import "AnimatedItemCell.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "GifCreationManager.h"
#import "iOSRedditAPI.h"
#import "SceneCapture.h"

@interface AnimatedItemCell ()

@property (nonatomic, assign) NSTimeInterval animationLoadingTimestamp;
@property (nonatomic, assign) BOOL shouldStartAnimatingAfterLoad;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end

@implementation AnimatedItemCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void)awakeFromNib
{
	// not currently used.
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) prepareForReuse
{
	self.animationLoadingTimestamp = 0;
	self.preview.image = nil;
	self.animationLoaded = NO;
	self.shouldStartAnimatingAfterLoad = NO;
	self.audioPlayer = nil;
	[self.preview stopAnimating];
	[self.preview setAnimationImages:nil];
}

-(void)startPreviewAnimation
{
	if (!self.animationLoaded)
	{
		self.shouldStartAnimatingAfterLoad = YES;
	}
	else
	{
		[self.audioPlayer play];
		[self.preview startAnimating];
	}
}

-(void)stopPreviewAnimation
{
	self.shouldStartAnimatingAfterLoad = NO;
	[self.preview stopAnimating];
	[self.audioPlayer stop];
}

-(void)loadFullAnimationInBackground:(NSString *)itemEncoderID
{
	if (self.animationLoaded)
	{
		return;
	}
	
	if ([NSThread isMainThread])
	{
		NSAssert(NO, @"loadAnimationInBackground should be called on the background thread.");
		return;
	}
	
#pragma message "Here is a spot to reenable the audio"
	/*
	NSString *theGIF = [GifCreationManager storageLocationForEncoderID:itemEncoderID imageIndex:0];
	
	NSString *audioURL = [theGIF stringByAppendingString:@"rawaudio"];
	NSFileManager *mgr = [NSFileManager defaultManager];

	if ([mgr fileExistsAtPath:audioURL])
	{
		NSError *error = nil;
		AVAudioPlayer *mplayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:audioURL] error:&error];
		
		if (error)
		{
			DLog(@"audio error: %@", error);
		}
		else
		{
			mplayer.delegate = self;
			[mplayer prepareToPlay];
			self.audioPlayer = mplayer;
		}
	}
	else
	{
		self.audioPlayer = nil;
	}
	 */
	
	NSTimeInterval nti = [NSDate timeIntervalSinceReferenceDate];
	self.animationLoadingTimestamp = nti;
	
	FeedItem *item = [FeedItem withEncoderID:itemEncoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
	NSArray *frames = [item buildAnimationFrames];
	
	if (frames && self.animationLoadingTimestamp==nti)
	{
		[self.preview setAnimationImages:frames];
		[self.preview setAnimationDuration:[frames count] * SceneCaptureFrameInterval];
		if (self.shouldStartAnimatingAfterLoad)
		{
			self.shouldStartAnimatingAfterLoad = NO;
			[self.audioPlayer performSelectorOnMainThread:@selector(play) withObject:nil waitUntilDone:NO];
			[self.preview performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];
		}
		self.animationLoaded = YES;
	}	
}

// TODO: this is curently not optimized for minimal usage. (might not be needed)
-(void)loadMinimalAnimationInBackground:(NSString *)itemEncoderID
{
	if (self.animationLoaded)
	{
		return;
	}
	
	if ([NSThread isMainThread])
	{
		NSAssert(NO, @"loadAnimationInBackground should be called on the background thread.");
		return;
	}
	
	NSTimeInterval nti = [NSDate timeIntervalSinceReferenceDate];
	self.animationLoadingTimestamp = nti;
	
	FeedItem *item = [FeedItem withEncoderID:itemEncoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
	NSArray *frames = [item buildAnimationFrames];
	
	if (frames && self.animationLoadingTimestamp==nti)
	{
		[self.preview setAnimationImages:frames];
		[self.preview setAnimationDuration:[frames count] * SceneCaptureFrameInterval];
		if (self.shouldStartAnimatingAfterLoad)
		{
			self.shouldStartAnimatingAfterLoad = NO;
			[self.audioPlayer performSelectorOnMainThread:@selector(play) withObject:nil waitUntilDone:NO];
			[self.preview performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];
		}
		self.animationLoaded = YES;
	}	
}

-(void)loadFullEntryInBackground:(NSString *)redditID
{
	if (self.animationLoaded)
	{
		return;
	}
	
	if ([NSThread isMainThread])
	{
		[self performSelectorInBackground:@selector(loadFullEntryInBackground:) withObject:redditID];
		return;
	}
	
	RedditPost *post = [RedditPost findFirstByAttribute:@"redditID" withValue:redditID inContext:[NSManagedObjectContext contextForCurrentThread]];
	
	// We keep checking that the nti hasn't changed, when the cell is reused it changes.
	NSTimeInterval nti = [NSDate timeIntervalSinceReferenceDate];
	self.animationLoadingTimestamp = nti;
	
	UIImage *previewFrame = post.previewFrame;
	
	if (previewFrame && self.animationLoadingTimestamp==nti)
	{
		[self.preview performSelectorOnMainThread:@selector(setImage:) withObject:previewFrame waitUntilDone:NO];
		
		NSArray *frames = [post buildAnimationFrames];
		if (!frames)
		{
			// If we get here the animation was cached.
			if (self.animationLoadingTimestamp==nti)
			{
				frames = post.animationFrames;
			}
		}
		
		if (frames && self.animationLoadingTimestamp==nti)
		{
			[self.preview setAnimationImages:frames];
			[self.preview setAnimationDuration:[frames count] * SceneCaptureFrameInterval];
			if (self.shouldStartAnimatingAfterLoad)
			{
				self.shouldStartAnimatingAfterLoad = NO;
				[self.preview performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];
			}
			self.animationLoaded = YES;
		}
	}
}

-(void)loadMinimalEntryInBackground:(NSString *)redditID
{
	if (self.animationLoaded)
	{
		return;
	}
	
	if ([NSThread isMainThread])
	{
		[self performSelectorInBackground:@selector(loadMinimalEntryInBackground:) withObject:redditID];
		return;
	}
	
	RedditPost *post = [RedditPost findFirstByAttribute:@"redditID" withValue:redditID inContext:[NSManagedObjectContext contextForCurrentThread]];
	
	// We keep checking that the nti hasn't changed, when the cell is reused it changes.
	NSTimeInterval nti = [NSDate timeIntervalSinceReferenceDate];
	self.animationLoadingTimestamp = nti;
	
	UIImage *previewFrame = [post cachedPreviewFrame];
	
	if (previewFrame && self.animationLoadingTimestamp==nti)
	{
		[self.preview performSelectorOnMainThread:@selector(setImage:) withObject:previewFrame waitUntilDone:NO];
	}
}

-(void)configureWithItem:(FeedItem *)item detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	if (level==AnimatedItemCellRenderDetailLevel_Full)
	{
		[self performSelectorInBackground:@selector(loadFullAnimationInBackground:) withObject:item.encoderID];
	}
	else
	{
		[self performSelectorInBackground:@selector(loadMinimalAnimationInBackground:) withObject:item.encoderID];
	}
}

-(void)configureWithReddit:(RedditPost *)reddit detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	if (level==AnimatedItemCellRenderDetailLevel_Full)
	{
		[self loadFullEntryInBackground:reddit.redditID];
	}
	else
	{
		[self loadMinimalEntryInBackground:reddit.redditID];
	}
}

-(void)setIsOnscreen:(BOOL)visible
{
	if (visible && !self.preview.isAnimating)
	{
		[self startPreviewAnimation];
	}
	
	if (!visible && self.preview.isAnimating)
	{
		[self stopPreviewAnimation];
	}
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	NSAssert(NO, @"Override this method in your subclass");
	return NO;
}

@end