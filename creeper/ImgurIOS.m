//
//  ImgurIOS.m
//  creeper
//
//  Created by Douglas Pedley on 3/1/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "ImgurIOS.h"
#import "NSData+Base64.h"
#import "AFNetworking.h"
#import "ImgurEntry.h"
#import "ImgurAPICredentials.h"

@interface ImgurIOS ()

@end

@implementation ImgurEntry (LocalImageCacheAdditions)

-(void)saveImageData:(NSData *)imgData toCache:(NSString *)cacheName
{
	NSString *fileLocation = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@", cacheName];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	if (![mgr fileExistsAtPath:fileLocation])
	{
		[imgData writeToFile:fileLocation atomically:NO];
	}
}

-(UIImage *)loadFromCache:(NSString *)cacheName
{
	NSString *fileLocation = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@", cacheName];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	if ([mgr fileExistsAtPath:fileLocation])
	{
		NSData *imgData = [NSData dataWithContentsOfFile:fileLocation];
		return [UIImage imageWithData:imgData];
	}
	return nil;
}

-(void)removeFromCache:(NSString *)cacheName
{
	NSString *fileLocation = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@", cacheName];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	if ([mgr fileExistsAtPath:fileLocation])
	{
		[mgr removeItemAtPath:fileLocation error:nil];
	}
}

@dynamic image;
-(UIImage *)image
{
	UIImage *cachedImage = [self loadFromCache:self.deletehash];
	if (!cachedImage)
	{
		NSURL * imageURL = [NSURL URLWithString:self.link];
		NSData * imageData = [NSData dataWithContentsOfURL:imageURL];
		
		if (imageData)
		{
			[self saveImageData:imageData toCache:self.deletehash];
			return [UIImage imageWithData:imageData];
		}
	}
	
	return cachedImage;
}

@end

@implementation ImgurIOS

+(NSString*)postValueEncoding:(NSString *)value
{
	NSString *escaped = [value stringByReplacingOccurrencesOfString:@"&" withString:@"%26"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"!" withString:@"%21"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"%27"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"(" withString:@"%28"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"*" withString:@"%2A"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"@" withString:@"%40"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@":" withString:@"%3A"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@";" withString:@"%3B"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
	escaped = [escaped stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
	
	return escaped;
	
}

+(void)deleteImageWithHashToken:(NSString *)hashToken deleteComplete:(void (^)(BOOL success))completion
{
	NSString *urlString = [NSString stringWithFormat:@"https://api.imgur.com/3/image/%@", hashToken];
	NSURL *url = [NSURL URLWithString:urlString];
	
	NSMutableURLRequest* urlRequest = [[NSMutableURLRequest alloc]initWithURL:url];
	[urlRequest setHTTPMethod:@"DELETE"];
	[urlRequest setValue:[NSString stringWithFormat:@"Client-ID %@", ImgurClientID] forHTTPHeaderField:@"Authorization"];
	
	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
		
		NSNumber *status = [JSON objectForKey:@"status"];
		NSNumber *success = [JSON objectForKey:@"success"];
		BOOL imageGone = [success boolValue];
		
		if (!imageGone)
		{
			int statusCode = [status integerValue];
			if (statusCode==200)
			{
				// Let's assume it's gone here too
				imageGone = YES;
			}
			else if (statusCode==404)
			{
				// 404 means not found, so it's gone
				imageGone = YES;
			}
		}
		
		if (imageGone)
		{
			NSLog(@"Imgur Delete Response: %@", JSON);
			
			ImgurEntry *newEntry = [ImgurEntry withAttributeNamed:@"deletehash" matchingValue:hashToken];
			[newEntry removeFromCache:newEntry.deletehash];
			[newEntry remove]; // This removes and saves.
			completion(YES);
		}
		else
		{
			completion(NO);
		}
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
		NSLog(@"er res: %@", JSON);
		
		NSNumber *status = [JSON objectForKey:@"status"];
		NSNumber *success = [JSON objectForKey:@"success"];
		BOOL imageGone = [success boolValue];
		
		if (!imageGone)
		{
			int statusCode = [status integerValue];
			if (statusCode==200)
			{
				// Let's assume it's gone here too
				imageGone = YES;
			}
			else if (statusCode==404)
			{
				// 404 means not found, so it's gone
				imageGone = YES;
			}
		}
		
		if (imageGone)
		{
			NSLog(@"Imgur Delete Response: %@", JSON);
			
			ImgurEntry *newEntry = [ImgurEntry withAttributeNamed:@"deletehash" matchingValue:hashToken];
			[newEntry removeFromCache:newEntry.deletehash];
			[newEntry remove]; // This removes and saves.
			completion(YES);
		}
		else
		{
			completion(NO);
		}
		
	}];
	
	[operation start];
}

+(void)uploadImageData:(NSData *)data name:(NSString *)theName title:(NSString *)theTitle description:(NSString *)theDescription uploadComplete:(void (^)(BOOL success))completion
{
	NSMutableString *optionalParams = [NSMutableString string];
	
	if (theName && [theName length]>0)
	{
		[optionalParams appendFormat:@"name=%@&", [theName stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
	}
	else
	{
		theName = nil;
	}
	
	if (theTitle && [theTitle length]>0)
	{
		[optionalParams appendFormat:@"title=%@&", [theTitle stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
	}
	else
	{
		theTitle = nil;
	}
	
	if (theDescription && [theDescription length]>0)
	{
		[optionalParams appendFormat:@"description=%@&", [theDescription stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
	}
	else
	{
		theDescription = nil;
	}
	
//	NSString* post_data = [NSString stringWithFormat:@"%@image=%@",
//						   optionalParams,
//						   img
//						   ];
	NSString *base64EncodedImage = [data base64EncodingWithLineLength:0];
//	NSLog(@"base64:\n\n%@\n\n", [self postValueEncoding:base64EncodedImage]);
	NSString* post_data = [NSString stringWithFormat:@"%@type=base64&image=%@",
						   optionalParams,
						   [self postValueEncoding:base64EncodedImage]
						   ];
	NSURL *url = [NSURL URLWithString:@"https://api.imgur.com/3/upload"];
	
	NSMutableURLRequest* urlRequest = [[NSMutableURLRequest alloc]initWithURL:url];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setHTTPBody:[post_data dataUsingEncoding:NSASCIIStringEncoding]];
	[urlRequest setValue:[NSString stringWithFormat:@"Client-ID %@", ImgurClientID] forHTTPHeaderField:@"Authorization"];
	
	__block NSTimeInterval createStamp = [[NSDate date] timeIntervalSince1970];
	
	AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:urlRequest success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
	{
		NSNumber *success = [JSON objectForKey:@"success"];
		if ([success boolValue])
		{
			NSDictionary *entryDict = JSON[@"data"];
			
			ImgurEntry *newEntry = [ImgurEntry addNew];
			newEntry.deletehash = entryDict[@"deletehash"];
			newEntry.imgurID = entryDict[@"id"];
			newEntry.link = entryDict[@"link"];
			newEntry.timestamp = [NSNumber numberWithDouble:createStamp];
			newEntry.imgName = theName;
			newEntry.imgTitle = theTitle;
			newEntry.imgDescription = theDescription;
			[ImgurEntry save];
			
			// Cache the image data for later
			[newEntry saveImageData:data toCache:newEntry.deletehash];
			NSLog(@"Saved: %@", JSON);
			completion(YES);
		}
		else
		{
			completion(NO);
		}
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
		completion(NO);
		NSLog(@"er res: %@", JSON);
	}];
	
	[operation start];
}

@end
