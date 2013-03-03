//
//  ImgurCell.m
//  creeper
//
//  Created by Douglas Pedley on 3/2/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImgurCell.h"
#import "ImgurIOS.h"
#import "ImgurEntry.h"
#import "NSDate+TimeAgo.h"

@interface ImgurCell ()

@end

@implementation ImgurCell

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

-(void)configureWithEntry:(ImgurEntry *)entry
{
	[self.imageView setImage:entry.image];
	// Set the Info
	NSString *theInfo = @"";
	
	if (entry.imgTitle && [entry.imgTitle length]>0)
	{
		theInfo = [theInfo stringByAppendingFormat:@"%@\n", entry.imgTitle];
	}
	
	if (entry.imgDescription && [entry.imgDescription length]>0)
	{
		theInfo = [theInfo stringByAppendingFormat:@"%@\n", entry.imgDescription];
	}
	
	if ([theInfo length]==0)
	{
		theInfo = @"No information available";
	}
	
	NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:theInfo];
	[self.infoLabel setAttributedText:attrString];
	
	// Set the timestamp
	NSTimeInterval epochTime = [[entry timestamp] doubleValue];
	NSDate *creationDate = [NSDate dateWithTimeIntervalSince1970:epochTime];
	self.timestampLabel.text = [NSString stringWithFormat:@"Created: %@", [creationDate timeAgo]];
}
@end
