//
//  GifProcessingCell.m
//  creeper
//
//  Created by Douglas Pedley on 3/30/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "GifProcessingCell.h"
#import "NSDate+TimeAgo.h"
#import "CreeperDataExtensions.h"

@interface GifProcessingCell ()

@property (nonatomic, strong) IBOutlet UIImageView *preview;
@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;

@end

@implementation GifProcessingCell

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
	self.infoLabel.text = [NSString stringWithFormat:@"%@ of %@ frames encoded", item.frameEncodingCount, item.frameCount];
	self.timestampLabel.text = [NSString stringWithFormat:@"Created: %@", [item.timestamp timeAgo]];
	self.imageView.image = item.currentImage;
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return (item.feedItemType==FeedItemType_Encoding);
}

-(void)setIsOnscreen:(BOOL)visible
{

}

@end
