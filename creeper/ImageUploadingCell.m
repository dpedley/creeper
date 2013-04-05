//
//  ImageUploadingCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/2/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImageUploadingCell.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "NSDate+TimeAgo.h"
#import "ImgurIOS.h"
#import "GifCreationManager.h"

@interface ImageUploadingCell ()

@property (nonatomic, strong) IBOutlet UIImageView *preview;
@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UIButton *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activity;

@property (nonatomic, strong) NSString *encoderID;

-(IBAction)actionButtonEvent:(id)sender;

@end

@implementation ImageUploadingCell

-(NSString *)uniqueName
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
	CFStringRef uuidString = CFUUIDCreateString(NULL, theUUID);
	CFRelease(theUUID);
	return [NSString stringWithFormat:@"%@_%@", creeperPrefix, uuidString];
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

-(void)attachFeedItemToImgur:(ImgurEntry *)imgur
{
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(attachFeedItemToImgur:) withObject:imgur waitUntilDone:NO];
		return;
	}
	
	FeedItem *item = [FeedItem withEncoderID:self.encoderID];
	[item setImgur:imgur];
	item.feedItemType = FeedItemType_Online;
	[FeedItem save];
}

-(IBAction)actionButtonEvent:(id)sender
{
	[self.actionButton setHidden:YES];
	[self.activity setHidden:NO];
	[self.infoLabel setHidden:NO];
	[self.activity startAnimating];
	NSString *dataPath = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:0];
	NSData *gifData = [NSData dataWithContentsOfFile:dataPath];
	FeedItem *uploadingItem = [FeedItem withEncoderID:self.encoderID];
	uploadingItem.feedItemType = FeedItemType_Uploading;
	[FeedItem save];
	
	if (gifData)
	{
		__weak ImageUploadingCell *blockSelf = self;
		__block NSString *newName = [self uniqueName];
		[ImgurIOS uploadImageData:gifData name:newName title:nil description:nil
				   uploadComplete:^(BOOL success, ImgurEntry *imgur) {
			if (success)
			{
				[blockSelf attachFeedItemToImgur:imgur];
			}
		}];
	}
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return ( (item.feedItemType==FeedItemType_Encoded) | (item.feedItemType==FeedItemType_Uploading) );
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
