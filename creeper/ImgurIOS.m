//
//  ImgurIOS.m
//  creeper
//
//  Created by Douglas Pedley on 3/1/13.
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

#import "ImgurIOS.h"
#import "NSData+Base64.h"
#import "AFNetworking.h"
#import "ImgurEntry.h"
#import "ExternalServices.h"

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

-(NSData *)loadDataFromCache:(NSString *)cacheName
{
	NSString *fileLocation = [NSHomeDirectory() stringByAppendingFormat:@"/Documents/%@", cacheName];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	if ([mgr fileExistsAtPath:fileLocation])
	{
		return [NSData dataWithContentsOfFile:fileLocation];
	}
	return nil;
}

-(UIImage *)loadFromCache:(NSString *)cacheName
{
	NSData *imgData = [self loadDataFromCache:cacheName];
	
	if (imgData)
	{
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
		return [UIImage imageWithData:self.imageData];
	}
	
	return cachedImage;
}

@dynamic imageData;
-(NSData *)imageData
{
	NSData *imageData = [self loadDataFromCache:self.deletehash];
	
	if (!imageData)
	{
		NSURL *imageURL = [NSURL URLWithString:self.link];
		imageData = [NSData dataWithContentsOfURL:imageURL];
		
		if (imageData)
		{
			[self saveImageData:imageData toCache:self.deletehash];
		}
	}
	
	return imageData;
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
	[urlRequest setValue:[NSString stringWithFormat:@"Client-ID %@", IMGUR_CLIENTID] forHTTPHeaderField:@"Authorization"];
	
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
			DLog(@"Imgur Delete Response: %@", JSON);
			
			ImgurEntry *newEntry = [ImgurEntry withAttributeNamed:@"deletehash" matchingValue:hashToken];
			[newEntry removeFromCache:newEntry.deletehash];
			completion(YES);
		}
		else
		{
			completion(NO);
		}
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
		DLog(@"er res: %@", JSON);
		
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
			DLog(@"Imgur Delete Response: %@", JSON);
			
			ImgurEntry *newEntry = [ImgurEntry withAttributeNamed:@"deletehash" matchingValue:hashToken];
			[newEntry removeFromCache:newEntry.deletehash];
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
//	DLog(@"base64:\n\n%@\n\n", [self postValueEncoding:base64EncodedImage]);
	NSString* post_data = [NSString stringWithFormat:@"%@type=base64&image=%@",
						   optionalParams,
						   [self postValueEncoding:base64EncodedImage]
						   ];
	NSURL *url = [NSURL URLWithString:@"https://api.imgur.com/3/upload"];
	
	NSMutableURLRequest* urlRequest = [[NSMutableURLRequest alloc]initWithURL:url];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setHTTPBody:[post_data dataUsingEncoding:NSASCIIStringEncoding]];
	[urlRequest setValue:[NSString stringWithFormat:@"Client-ID %@", IMGUR_CLIENTID] forHTTPHeaderField:@"Authorization"];
	
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
			DLog(@"Saved: %@", JSON);
			completion(YES);
		}
		else
		{
			completion(NO);
		}
		
	} failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
		completion(NO);
		DLog(@"er res: %@", JSON);
	}];
	
	[operation start];
}

@end
