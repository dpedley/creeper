//
//  CreeperDataExtensions.h
//  creeper
//
//  Created by Douglas Pedley on 3/30/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImgurEntry.h"
#import "FeedItem.h"
#import "RedditPost.h"

typedef enum
{
	FeedItemType_Encoding   = 1001,
	FeedItemType_Encoded    = 1002,
	FeedItemType_Uploading  = 1003,
	FeedItemType_Online     = 1004,
	FeedItemType_Reddit     = 1005
}
FeedItemType;

@class FeedItem;

@interface FeedItem (CreeperDataExtensions)

@property (nonatomic, assign) FeedItemType feedItemType;
@property (nonatomic, readonly) UIImage *currentImage;

-(NSArray *)buildAnimationFrames;

+(FeedItem *)withEncoderID:(NSString *)theEncoderID;

@end

@interface RedditPost (CreeperDataExtensions)

@property (nonatomic, readonly) NSURL *mobileURL;

@end