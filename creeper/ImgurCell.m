//
//  ImgurCell.m
//  creeper
//
//  Created by Douglas Pedley on 3/2/13.
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

#import "ImgurCell.h"
#import "ImgurIOS.h"
#import "ImgurEntry.h"
#import "NSDate+TimeAgo.h"

@interface ImgurCell ()

@property (nonatomic, strong) IBOutlet UIButton *deleteCover;
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
	[self.preview setImage:entry.image];
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

-(void)willTransitionToState:(UITableViewCellStateMask)state
{
	switch (state)
	{
		case UITableViewCellStateDefaultMask:
		{
			[UIView animateWithDuration:0.2 animations:^{
				[self.deleteCover setAlpha:0.0f];
			}];
		}
			break;
			
		case UITableViewCellStateShowingEditControlMask:
		{
			[UIView animateWithDuration:0.2 animations:^{
				[self.deleteCover setAlpha:1.0f];
			}];
		}
			break;
			
//		case <#constant#>:
//		{
//			<#statements#>
//		}
			break;
			
		default:
			break;
	}
	[super willTransitionToState:state];
}

@end
