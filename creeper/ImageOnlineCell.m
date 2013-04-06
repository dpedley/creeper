//
//  ImageOnlineCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/3/13.
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

#import "ImageOnlineCell.h"
#import "ImgurEntry.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "NSDate+TimeAgo.h"
#import "GifCreationManager.h"

@interface ImageOnlineCell ()

@property (nonatomic, strong) IBOutlet UIImageView *preview;
@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UIButton *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activity;

@property (nonatomic, strong) NSString *encoderID;

@end

@implementation ImageOnlineCell

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

-(void)configureWithItem:(FeedItem *)item
{
	if (!self.encoderID) // This must be our first load.
	{
		[self.actionButton setHidden:NO];
		[self.activity setHidden:YES];
		[self.infoLabel setHidden:YES];
	}
	self.encoderID = item.encoderID;
	NSArray *frames = [item buildAnimationFrames];
	[self.preview setImage:[frames objectAtIndex:(int)floor([frames count]/2)]];
	[self.preview setAnimationImages:frames];
	[self.preview setAnimationDuration:[frames count]*0.125];
	[self.preview startAnimating];
	
	// Set the timestamp
	self.timestampLabel.text = [NSString stringWithFormat:@"Created: %@", [item.timestamp timeAgo]];
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return (item.feedItemType==FeedItemType_Online);
}

-(void)setIsOnscreen:(BOOL)visible
{
	if (visible && !self.preview.isAnimating)
	{
		[self.preview startAnimating];
	}
	
	if (!visible && self.preview.isAnimating)
	{
		[self.preview stopAnimating];
	}
}

@end
