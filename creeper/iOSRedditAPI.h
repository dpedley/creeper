//
//  iOSRedditAPI.h
//  creeper
//
//  Created by Douglas Pedley on 3/14/13.
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

#import <Foundation/Foundation.h>

@class RedditPost;

typedef void (^iOSRedditGenericCompletion)(BOOL success);
typedef void (^iOSRedditPostCompletion)(BOOL success, RedditPost *post);
typedef void (^iOSRedditLoadPostData)(NSDictionary *postDictionary, BOOL cached);
typedef void (^iOSRedditSubredditPosts)(NSArray *postArray);

@interface iOSRedditAPI : NSObject

+(iOSRedditAPI *)shared;

-(BOOL)hasModHash;
-(void)submitLink:(NSString *)link toSubreddit:(NSString *)sr withTitle:(NSString *)title captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock;
-(void)login:(NSString *)user passwd:(NSString *)passwd success:(void (^)(BOOL success))completionBlock;
-(void)loadCurrentDataForRedditPostID:(NSString *)id completion:(iOSRedditLoadPostData)completion;
-(void)loadSubreddit:(NSString *)subreddit completion:(iOSRedditSubredditPosts)completion;
-(void)deleteByName:(NSString *)theRedditName parentVC:(UIViewController *)vc deleted:(iOSRedditGenericCompletion)completionBlock;
-(void)addCommentTo:(NSString *)theRedditName comment:(NSString *)comment parentVC:(UIViewController *)vc complete:(iOSRedditGenericCompletion)completionBlock;
-(void)addPostValidation:(RedditPost *)post parentVC:(UIViewController *)vc complete:(iOSRedditGenericCompletion)completionBlock;

+(NSString *)storageLocationForAnimationFrames:(RedditPost *)entry;
+(NSString *)storageLocation:(RedditPost *)entry;
+(NSString *)storageLocationForPreview:(RedditPost *)entry;
+(NSString *)storageLocationForOnlinePreview:(RedditPost *)entry;

@end