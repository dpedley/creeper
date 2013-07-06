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
#import "iOSRedditAPI.h"
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
	NSString *previewPath = [GifCreationManager storageLocationForEncoderID:self.encoderID previewImageIndex:i];

	while ([mgr fileExistsAtPath:theGIF])
	{
		NSMutableArray *moreFrames = [NSMutableArray array];
		[GifDecode decodeGifFramesFromFile:theGIF storeFramesIn:moreFrames storeInfo:nil separateFrameOnly:NO];
		if (moreFrames && [moreFrames count]>0)
		{
			[theFrames addObjectsFromArray:moreFrames];
		}
		
		if (![mgr fileExistsAtPath:previewPath])
		{
			if (theFrames && [theFrames count]>0)
			{
				UIImage *previewFrm = [theFrames objectAtIndex:floor([theFrames count]/2)];
				NSData *pngData = UIImagePNGRepresentation(previewFrm);
				if (pngData)
				{
					[pngData writeToFile:previewPath atomically:NO];
				}
			}
		}
		
		i++;
		theGIF = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:i];
	}
	
	return theFrames;
}

+(FeedItem *)withEncoderID:(NSString *)theEncoderID inContext:(NSManagedObjectContext *)context
{
	return [FeedItem findFirstByAttribute:@"encoderID" withValue:theEncoderID inContext:context];
}

-(void)attachToImgur:(ImgurEntry *)imgur
{
	[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
		FeedItem *localFeedItem = [FeedItem withEncoderID:self.encoderID inContext:localContext];
		[localFeedItem setImgur:imgur];
		localFeedItem.feedItemType = FeedItemType_Online;
	} completion:^(BOOL success, NSError *error) {
		DLog(@"attachToImgur complete.");
	}];
}


@end

@implementation RedditPost (CreeperDataExtensions)

/*
 // From submittion response
id = 1aechj;
name = "t3_1aechj";
url = "https://ssl.reddit.com/r/creeperapp/comments/1aechj/wood_stove_diy/";

 // From http://api.reddit.com/r/creeperapp/comments/1aechj/wood_stove_diy/
 
 [
	{
	"kind": "Listing",
	"data": {
		"modhash": "", 
		"children": [
			{
			"kind": "t3",
			"data": {
				"domain": "i.imgur.com", 
				"banned_by": null, 
				"media_embed": {}, 
				"subreddit": "creeperapp", 
				"selftext_html": null, 
				"selftext": "", 
				"likes": null, 
				"link_flair_text": null, 
				"id": "1aechj", 
				"clicked": false, 
				"title": "Wood stove DIY", 
				"media": null, 
				"score": 0, 
				"approved_by": null, 
				"over_18": false, 
				"hidden": false, 
				"thumbnail": "", 
				"subreddit_id": "t5_2wm8c", 
				"edited": false, 
				"link_flair_css_class": null, 
				"author_flair_css_class": null, 
				"downs": 1, 
				"saved": false, 
				"is_self": false, 
				"permalink": "/r/creeperapp/comments/1aechj/wood_stove_diy/", 
				"name": "t3_1aechj", 
				"created": 1363417900.0, 
				"url": "http://i.imgur.com/OOBkB7M.gif", 
				"author_flair_text": null, 
				"author": "dpedley", 
				"created_utc": 1363414300.0, 
				"ups": 1, 
				"num_comments": 0, 
				"num_reports": null, 
				"distinguished": null
			}
		}
	], 
 "after": null, "before": null}}, {"kind": "Listing", "data": {"modhash": "", "children": [], "after": null, "before": null}}]
 
 */

static NSString *baseURL = @"https://ssl.reddit.com";
static int baseURL_length = 22;

// NOTE withDictionary is add or update, not overwrite
+(RedditPost *)withDictionary:(NSDictionary *)postDictionary inContext:(NSManagedObjectContext *)context
{
	NSString *redditID = [postDictionary objectForKey:@"id"];
		
	if (redditID)
	{
		RedditPost *rp = [RedditPost findFirstByAttribute:@"redditID" withValue:redditID inContext:context];

		if (!rp)
		{
			rp = [RedditPost createInContext:context];
			rp.redditID = redditID;
			rp.hotOrder = [NSNumber numberWithInt:-1];
		}

		// Name
		NSString *v = [postDictionary objectForKey:@"name"];
		if (v)
		{
			rp.redditName = v;
		}
		
		// Domain
		v = [postDictionary objectForKey:@"domain"];
		if (v)
		{
			rp.domain = v;
		}
		
		// Author
		v = [postDictionary objectForKey:@"author"];
		if (v)
		{
			rp.author = v;
		}
		
		// Title
		v = [postDictionary objectForKey:@"title"];
		if (v)
		{
			rp.redditTitle = v;
		}
		
		// Score
		NSNumber *n = [postDictionary objectForKey:@"score"];
		if (n)
		{
			rp.score = n;
		}
				
		// NSFW
		n = [postDictionary objectForKey:@"over_18"];
		if (n)
		{
			rp.over18Number = n;
		}
		
		NSString *permalink = [postDictionary objectForKey:@"permalink"];
		if (!permalink)
		{
			// This is the smaller submit response.
			permalink = [postDictionary objectForKey:@"url"];
			if (permalink && permalink.length>baseURL_length && [[permalink substringToIndex:baseURL_length] isEqualToString:baseURL])
			{
				permalink = [permalink substringFromIndex:baseURL_length];
				rp.redditURL = permalink;
				if (!rp.created)
				{
					rp.created = [NSDate date];
				}
			}
		}
		else
		{
			rp.redditURL = permalink;
			
			// Imgur
			v = [postDictionary objectForKey:@"url"];
			if (v)
			{
				rp.imgurLink = v;
			}
			
			n = [postDictionary objectForKey:@"created"]; // possibly created_utc?
			if (n)
			{
				NSTimeInterval timeZoneOffset = [[NSTimeZone systemTimeZone] secondsFromGMTForDate:[NSDate date]];
				rp.created = [NSDate dateWithTimeIntervalSince1970:[n doubleValue] + timeZoneOffset];
			}
		}
		
		return rp;
	}
	
	return nil;
}

@dynamic mobileURL;
-(NSURL *)mobileURL
{
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://i.reddit.com%@", self.redditURL]];
}

@dynamic fullRedditLink;
-(NSString *)fullRedditLink
{
	return [NSString stringWithFormat:@"http://reddit.com%@", self.redditURL];
}

@dynamic imgurID;
-(NSString *)imgurID
{
	// Let's not rebuild these for each access.
	static NSString *theIDregex =  @"^http:\\/\\/i.imgur.com\\/(.*).gif$";
	static NSRegularExpression *regex = nil; if (!regex)regex=[NSRegularExpression regularExpressionWithPattern:theIDregex options:0 error:nil];
	
	NSString *imgurURL = self.imgurLink;	
	NSRange wholeString = NSMakeRange(0, [imgurURL length]);
	NSArray *matches = [regex matchesInString:imgurURL options:0 range:wholeString];
	
	if (matches && [matches count]>0)
	{
		NSTextCheckingResult *match = [matches objectAtIndex:0];
		return [imgurURL substringWithRange:[match rangeAtIndex:1]];
	}
	
	return nil;
}

-(NSString *)previewImageURL
{
	if ([[self.imgurLink substringFromIndex:[self.imgurLink length]-4] isEqualToString:@".gif"])
	{
		return [NSString stringWithFormat:@"%@s.gif", [self.imgurLink substringToIndex:[self.imgurLink length]-4]];
	}
	return nil;
}

-(UIImage *)cachedPreviewFrame
{
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	NSString *previewPath = [iOSRedditAPI storageLocationForPreview:self];
	if (![mgr fileExistsAtPath:previewPath])
	{
		return nil;
	}
	return [UIImage imageWithContentsOfFile:previewPath];
}

@dynamic previewFrame;
-(UIImage *)previewFrame
{
	UIImage *thePreviewImage = [self cachedPreviewFrame];
	
	if (!thePreviewImage)
	{
		NSFileManager *mgr = [NSFileManager defaultManager];
		
		NSString *previewOnlinePath = [iOSRedditAPI storageLocationForOnlinePreview:self];
		
		if (![mgr fileExistsAtPath:previewOnlinePath])
		{
			DLog(@"loading preview: %@", [self previewImageURL]);
			NSData *previewData = [NSData dataWithContentsOfURL:[NSURL URLWithString:[self previewImageURL]]];
			[previewData writeToFile:previewOnlinePath atomically:YES];
			thePreviewImage = [UIImage imageWithData:previewData];
		}
		else
		{
			thePreviewImage = [UIImage imageWithContentsOfFile:previewOnlinePath];
		}
	}
	
	return thePreviewImage;
}

@dynamic nsfw;
-(BOOL)nsfw
{
	if (self.over18Number)
	{
		return [self.over18Number boolValue];
	}
	return NO;
}

@dynamic animationFrames;
-(NSArray *)animationFrames
{
	return [self internalBuildAnimationFramesIfNeeded:YES];
}

-(NSArray *)buildAnimationFrames
{
	return [self internalBuildAnimationFramesIfNeeded:NO];
}

-(NSArray *)cachedAnimationFrames
{
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	NSString *animationPath = [iOSRedditAPI storageLocationForAnimationFrames:self];
	NSMutableArray *theFrames = [NSMutableArray array];
	
	if ([mgr fileExistsAtPath:animationPath])
	{
		// They are already built
		NSArray *dataFrames = [NSArray arrayWithContentsOfFile:animationPath];
		
		if (dataFrames)
		{
			for (int i=0; i<[dataFrames count]; i++)
			{
				NSData *imgData = [dataFrames objectAtIndex:i];
				[theFrames addObject:[UIImage imageWithData:imgData]];
			}
		}
		
		return theFrames;
	}
	
	return nil;
}

-(NSArray *)internalBuildAnimationFramesIfNeeded:(BOOL)returnCached
{
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	NSString *animationPath = [iOSRedditAPI storageLocationForAnimationFrames:self];
	NSMutableArray *theFrames = [NSMutableArray array];
	
	if ([mgr fileExistsAtPath:animationPath])
	{
		// They are already built
		if (returnCached)
		{
			NSArray *dataFrames = [NSArray arrayWithContentsOfFile:animationPath];
			
			if (dataFrames)
			{
				for (int i=0; i<[dataFrames count]; i++)
				{
					NSData *imgData = [dataFrames objectAtIndex:i];
					[theFrames addObject:[UIImage imageWithData:imgData]];
				}
			}
			
			return theFrames;
		}
		return nil;
	}
	
	{
		NSString *theGIF = [iOSRedditAPI storageLocation:self];
		NSString *previewPath = [iOSRedditAPI storageLocationForPreview:self];
		
		if (![mgr fileExistsAtPath:theGIF])
		{
			NSData *gifData = [NSData dataWithContentsOfURL:[NSURL URLWithString:self.imgurLink]];
			[gifData writeToFile:theGIF atomically:NO];
		}
		
		[GifDecode decodeGifFramesFromFile:theGIF storeFramesIn:theFrames storeInfo:nil separateFrameOnly:NO];

		if (![mgr fileExistsAtPath:animationPath])
		{
			NSMutableArray *newDataFrames = [NSMutableArray array];
			for (int i=0; i<[theFrames count]; i++)
			{
				[newDataFrames addObject:UIImagePNGRepresentation([theFrames objectAtIndex:i])];
			}
			[newDataFrames writeToFile:animationPath atomically:YES];
		}

		if (![mgr fileExistsAtPath:previewPath])
		{
			if (theFrames && [theFrames count]>0)
			{
				UIImage *previewFrm = [theFrames objectAtIndex:floor([theFrames count]/2)];
				NSData *pngData = UIImagePNGRepresentation(previewFrm);
				if (pngData)
				{
					[pngData writeToFile:previewPath atomically:NO];
				}
			}
		}
	}
	
	return theFrames;
}

@end
