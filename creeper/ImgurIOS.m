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
#import <giflib-ios/GifDecode.h>

@interface ImgurIOS ()

@end

@implementation ImgurIOS

#pragma mark - Images for buttons

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
    [self reachableOnce:NO completion:^(Reachability *reachability) {
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
                
                completion(YES);
            }
            else
            {
                completion(NO);
            }
            
        }];
        
        [operation start];
    }];
}

+(void)reachableOnce:(BOOL)wifiOnly completion:(NetworkReachable)completionBlock
{
    // allocate a reachability object
    Reachability* reach = [Reachability reachabilityWithHostname:@"api.imgur.com"];
    
    if (wifiOnly)
    {
        reach.reachableOnWWAN = NO;
    }
    
    reach.reachableBlock = ^(Reachability*reach)
    {
        [reach stopNotifier];
        completionBlock(reach);
    };
    
    reach.unreachableBlock = ^(Reachability*reach){};
    
    // start the notifier which will cause the reachability object to retain itself!
    [reach startNotifier];
}

+(void)reachableViaWifi:(NetworkReachable)wifiBlock
{
    [self reachableOnce:YES completion:wifiBlock];
}


+(void)uploadImageData:(NSData *)data name:(NSString *)aName title:(NSString *)aTitle description:(NSString *)aDescription uploadComplete:(void (^)(BOOL success, ImgurEntry *imgur))completion
{
    [self reachableViaWifi:^(Reachability *reachability) {
        NSMutableString *optionalParams = [NSMutableString string];
        
        NSString *theName = aName;
        if (theName && [theName length]>0)
        {
            [optionalParams appendFormat:@"name=%@&", [theName stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
        }
        else
        {
            theName = nil;
        }
        
        NSString *theTitle = aTitle;
        if (theTitle && [theTitle length]>0)
        {
            [optionalParams appendFormat:@"title=%@&", [theTitle stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
        }
        else
        {
            theTitle = nil;
        }
        
        NSString *theDescription = aDescription;
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
                                                     
                                                     [MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
                                                         ImgurEntry *newEntry = [ImgurEntry createInContext:localContext];
                                                         newEntry.deletehash = entryDict[@"deletehash"];
                                                         newEntry.imgurID = entryDict[@"id"];
                                                         newEntry.link = entryDict[@"link"];
                                                         newEntry.timestamp = [NSNumber numberWithDouble:createStamp];
                                                         newEntry.imgName = theName;
                                                         newEntry.imgTitle = theTitle;
                                                         newEntry.imgDescription = theDescription;
                                                     } completion:^(BOOL success, NSError *error) {
                                                         ImgurEntry *savedEntry = [ImgurEntry findFirstByAttribute:@"imgurID" withValue:entryDict[@"id"]];
                                                         if (savedEntry)
                                                         {
                                                             // Cache the image data for later
                                                             DLog(@"Saved: %@", JSON);
                                                             completion(YES, savedEntry);
                                                         }
                                                     }];
                                                 }
                                                 else
                                                 {
                                                     completion(NO, nil);
                                                 }
                                                 
                                             } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
                                                 completion(NO, nil);
                                                 DLog(@"er res: %@ %@ %d", JSON, error, response.statusCode);
                                             }];
        
        [operation start];
    }];
}

@end
