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

@interface AnimatedItemCell ()

@property (nonatomic, assign) BOOL animationLoaded;
@property (nonatomic, assign) BOOL shouldStartAnimatingAfterLoad;

-(void)startPreviewAnimation;
-(void)stopPreviewAnimation;

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

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void) prepareForReuse
{
	self.preview.image = nil;
	self.animationLoaded = NO;
	self.shouldStartAnimatingAfterLoad = NO;
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
		[self.preview startAnimating];
	}
}

-(void)stopPreviewAnimation
{
	self.shouldStartAnimatingAfterLoad = NO;
	[self.preview stopAnimating];
}

-(void)loadAnimationInBackground:(FeedItem *)item
{
	self.animationLoaded = NO;
	if ([NSThread isMainThread])
	{
		[self performSelectorInBackground:@selector(loadAnimationInBackground:) withObject:item];
		return;
	}
	
	NSArray *frames = [item buildAnimationFrames];
	[self.preview setAnimationImages:frames];
	[self.preview setAnimationDuration:[frames count]*0.125];
	if (self.shouldStartAnimatingAfterLoad)
	{
		self.shouldStartAnimatingAfterLoad = NO;
		[self.preview performSelectorOnMainThread:@selector(startAnimating) withObject:nil waitUntilDone:NO];
	}
	self.animationLoaded = YES;
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

-(void)configureWithItem:(FeedItem *)item
{
	[self loadAnimationInBackground:item];
	[self.preview setImage:[GifCreationManager previewFrameForEncoderID:item.encoderID imageIndex:0]];
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	NSAssert(NO, @"Override this method in your subclass");
	return NO;
}

@end
