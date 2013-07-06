//
//  ImageUploadingCell.m
//  creeper
//
//  Created by Douglas Pedley on 4/2/13.
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

#import "ImageUploadingCell.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "NSDate+TimeAgo.h"
#import "ImgurIOS.h"
#import "GifCreationManager.h"
#import <QuartzCore/QuartzCore.h>
#import "ImgurSubmit.h"

@interface ImageUploadingCell ()

@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UIButton *actionButton;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;
@property (nonatomic, strong) IBOutlet UIActivityIndicatorView *activity;
@property (nonatomic, strong) IBOutlet UIView *hud;

@property (nonatomic, strong) NSString *encoderID;

@end

@implementation ImageUploadingCell

- (void) prepareForReuse
{
	[super prepareForReuse];
	[self.actionButton setHidden:NO];
	[self.hud setHidden:YES];
	self.encoderID = nil;
	self.timestampLabel.text = @"";
	[self.actionButton setBackgroundImage:nil forState:UIControlStateNormal];
	[self.actionButton setBackgroundImage:nil forState:UIControlStateHighlighted];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self)
	{
        // Initialization code
    }
    return self;
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	self.hud.layer.cornerRadius = 10.0;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

-(void)uploadBackground
{
    // allocate a reachability object
    Reachability* reach = [Reachability reachabilityWithHostname:@"www.google.com"];
    
    // set the blocks
    reach.reachableBlock = ^(Reachability*reach)
    {
        NSLog(@"REACHABLE!");
    };
    
    reach.unreachableBlock = ^(Reachability*reach)
    {
        NSLog(@"UNREACHABLE!");
    };
    
    // start the notifier which will cause the reachability object to retain itself!
    [reach startNotifier];
    FeedItem *existingItem = [FeedItem withEncoderID:self.encoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
    if (!existingItem.imgur && existingItem.feedItemType!=FeedItemType_Online)
    {
        NSString *dataPath = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:0];
        NSData *gifData = [NSData dataWithContentsOfFile:dataPath];
        if (gifData)
        {
            __block NSString *newName = [ImgurSubmit uniqueName];
            __block NSString *blockEncoderID = [[NSString alloc] initWithString:self.encoderID];
            [ImgurIOS uploadImageData:gifData name:newName title:nil description:nil
                       uploadComplete:^(BOOL success, ImgurEntry *imgur) {
                           if (success)
                           {
                               FeedItem *item = [FeedItem withEncoderID:blockEncoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
                               if (item)
                               {
                                   [item attachToImgur:imgur];
                               }
                               else
                               {
                                   // we must have been deleted
                                   // let's assume we should remove the online version too.
                                   [ImgurIOS deleteImageWithHashToken:imgur.deletehash deleteComplete:^(BOOL success) {}];
                                   [MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
                                       ImgurEntry *theImgur = [ImgurEntry findFirstByAttribute:@"imgurID" withValue:imgur.imgurID inContext:localContext];
                                       [theImgur deleteInContext:localContext];
                                   } completion:^(BOOL success, NSError *error) {
                                       DLog(@"Upload success, but item was removed.");
                                   }];
                               }
                           }
                           else
                           {
                               // TODO: retry etc.
                           }
                       }];
        }
    }
}

-(void)configureWithItem:(FeedItem *)item detailLevel:(AnimatedItemCellRenderDetailLevel)level
{
	[super configureWithItem:item detailLevel:level];
	if (!self.encoderID)
	{
		self.encoderID = item.encoderID;
		
		// Should we automatically upload?
		BOOL shouldAutoupload = [[NSUserDefaults standardUserDefaults] boolForKey:@"kCreeperUserDefaults_Autoupload"];
		
		if (shouldAutoupload)
		{
			[self.actionButton setHidden:YES];
			[self.hud setHidden:NO];
			[self.activity startAnimating];
			[self uploadBackground];
		}
		else
		{
			UIImage *buttonImage = [[UIImage imageNamed:@"button.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(18, 18, 18, 18)];
			UIImage *buttonImageHighlight = [[UIImage imageNamed:@"buttonHighlight.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(18, 18, 18, 18)];
			[self.actionButton setBackgroundImage:buttonImage forState:UIControlStateNormal];
			[self.actionButton setBackgroundImage:buttonImageHighlight forState:UIControlStateHighlighted];
			
			[self.actionButton setHidden:NO];
			[self.hud setHidden:YES];
		}
	}
	
	// Set the timestamp
	self.timestampLabel.text = [item.timestamp timeAgo];
}

-(BOOL)isCorrectCellForItem:(FeedItem *)item
{
	return ( (item.feedItemType==FeedItemType_Encoded) | (item.feedItemType==FeedItemType_Uploading) );
}

@end
