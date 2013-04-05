//
//  RedditPostCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/4/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "RedditPostCell.h"

#import "ImgurEntry.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "NSDate+TimeAgo.h"
#import "GifCreationManager.h"

@interface RedditPostCell ()

@property (nonatomic, strong) IBOutlet UIImageView *preview;
@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UIButton *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activity;

@property (nonatomic, strong) NSString *encoderID;

@end

@implementation RedditPostCell

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
	return (item.feedItemType==FeedItemType_Reddit);
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
