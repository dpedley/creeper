//
//  CreeperDataExtensions.m
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

#import "CreeperDataExtensions.h"
#import "GifCreationManager.h"
#import <giflib-ios/GifDecode.h>

@implementation FeedItem (CreeperDataExtensions)

@dynamic feedItemType;
-(FeedItemType)feedItemType
{
	return (FeedItemType)[self.itemType integerValue];
}
-(void)setFeedItemType:(FeedItemType)value
{
	self.itemType = [NSNumber numberWithInt:(int)value];
}

//@dynamic imageData;
//-(NSData *)imageData
//{
//	NSData *imageData = [self loadDataFromCache:self.deletehash];
//	
//	if (!imageData)
//	{
//		NSURL *imageURL = [NSURL URLWithString:self.link];
//		imageData = [NSData dataWithContentsOfURL:imageURL];
//		
//		if (imageData)
//		{
//			[self saveImageData:imageData toCache:self.deletehash];
//		}
//	}
//	
//	return imageData;
//}

@dynamic currentImage;
-(UIImage *)currentImage
{
	GifCreationQueue *queue = [GifCreationManager queueByID:self.encoderID];
	
	if (!queue || (queue.closed && !queue.lastOperation))
	{
		
	}
	return queue.lastEncodedFrame;
}

-(NSArray *)buildAnimationFrames
{
	NSMutableArray *theFrames = [NSMutableArray array];

	NSFileManager *mgr = [NSFileManager defaultManager];
	int i=0;
	NSString *theGIF = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:i];
	
	while ([mgr fileExistsAtPath:theGIF])
	{
		NSMutableArray *moreFrames = [NSMutableArray array];
		[GifDecode decodeGifFramesFromFile:theGIF storeFramesIn:moreFrames storeInfo:nil separateFrameOnly:NO];
		if (moreFrames && [moreFrames count]>0)
		{
			[theFrames addObjectsFromArray:moreFrames];
		}
		
		i++;
		theGIF = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:i];
	}
	
	return theFrames;
}

+(FeedItem *)withEncoderID:(NSString *)theEncoderID
{
	return [FeedItem withAttributeNamed:@"encoderID" matchingValue:theEncoderID];
}

@end

@implementation RedditPost (CreeperDataExtensions)

@dynamic mobileURL;
-(NSURL *)mobileURL
{
	NSRange r = [self.redditURL rangeOfString:@"reddit.com/"];
	
	if (r.location!=NSNotFound)
	{
		return [NSURL URLWithString:[NSString stringWithFormat:@"http://i.%@", [self.redditURL substringFromIndex:r.location]]];
	}
	
	return [NSURL URLWithString:self.redditURL];
}

@end
