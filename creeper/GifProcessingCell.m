//
//  GifProcessingCell.m
//  creeper
//
//  Created by Douglas Pedley on 3/30/13.
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

#import "GifProcessingCell.h"
#import "NSDate+TimeAgo.h"
#import "CreeperDataExtensions.h"
#import "AnimatedItemCell.h"
#import <QuartzCore/QuartzCore.h>

@interface GifProcessingCell ()

@property (nonatomic, strong) IBOutlet UIImageView *lastProcessedFrame;

@property (nonatomic, strong) IBOutlet UIView *hud;
@property (nonatomic, strong) IBOutlet UILabel *frameProgress;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;

@end

@implementation GifProcessingCell

- (void) prepareForReuse
{
	self.frameProgress.text = @"";
	self.imageView.image = nil;
	self.timestampLabel.text = @"";
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
	{
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)awakeFromNib
{
	self.hud.layer.cornerRadius = 10.0;
}

-(void)configureWithItem:(FeedItem *)item detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	if (level==AnimatedItemCellRenderDetailLevel_Full)
	{
		self.frameProgress.text = [NSString stringWithFormat:@"Processing %@ of %@", item.frameEncodingCount, item.frameCount];
		self.lastProcessedFrame.image = item.currentImage;
		
		// Set the timestamp
		self.timestampLabel.text = [item.timestamp timeAgo];
	}
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return (item.feedItemType==FeedItemType_Encoding);
}

@end
