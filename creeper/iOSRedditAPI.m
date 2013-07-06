//
//  iOSRedditAPI.m
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

#import "iOSRedditAPI.h"
#import "ExternalServices.h"
#import "iOSRedditCaptcha.h"
#import "iOSRedditLogin.h"
#import "RedditPost.h"
#import "CreeperDataExtensions.h"
#import <giflib-ios/GifEncode.h>
#import <giflib-ios/GifDecode.h>
#import <giflib-ios/giflib_ios.h>

#define REDDIT_POST_TTL 90

typedef void (^iOSRedditWebEngineDataBlock)(NSData *data, NSError *error);
typedef void (^iOSRedditDismissedBlock)();

@interface iOSRedditWebEngine : UIWebView <UIWebViewDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) NSMutableData *pageData;
@property (nonatomic, copy) iOSRedditWebEngineDataBlock dataBlock;

+(id)engineWithDataBlock:(iOSRedditWebEngineDataBlock)completion;

@end

@interface iOSRedditAPI ()

@property (nonatomic, strong) NSMutableDictionary *cachedRedditPosts;
@property (nonatomic, strong) iOSRedditWebEngine *engine;
@property (nonatomic, strong) NSString *modHash;
@property (nonatomic, strong) NSString *loginCookie;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *passwd;

-(void)establishConnection:(void (^)(BOOL connectionEstablished))connectionBlock;
-(void)submitLink:(NSString *)link toSubreddit:(NSString *)sr withTitle:(NSString *)title iden:(NSString *)iden captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock;

@end
@implementation iOSRedditAPI

#pragma mark - utilities

+(BOOL)wasCurrentUserPost:(RedditPost *)entry
{
	if ([[self shared].user isEqualToString:entry.author])
	{
		return YES;
	}
	return NO;
}

+(NSString *)iOSRedditAPIdir
{
	NSArray  *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir  = [documentPaths objectAtIndex:0];
	NSString *outputDir    = [documentsDir stringByAppendingPathComponent:@"reddit"];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	if (![mgr fileExistsAtPath:outputDir])
	{
		[mgr createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return outputDir;
}

+(NSString *)iOSRedditAPIcachedir
{
	NSString *outputDir = [[self iOSRedditAPIdir] stringByAppendingPathComponent:@"cache"];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	if (![mgr fileExistsAtPath:outputDir])
	{
		[mgr createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return outputDir;
}

+(NSString *)storageLocationExpirableCacheAnimationFrames:(RedditPost *)entry
{
	NSString *outputDir = [self iOSRedditAPIcachedir];
	return [outputDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@.plist", entry.redditID]];
}

+(NSString *)storageLocationExpirableCache:(RedditPost *)entry
{
	NSString *outputDir = [self iOSRedditAPIcachedir];
	return [outputDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@.gif", entry.redditID]];
}

+(NSString *)storageLocationExpirableCachePreview:(RedditPost *)entry
{
	NSString *outputDir = [self iOSRedditAPIcachedir];
	return [outputDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@_preview.gif", entry.redditID]];
}

+(NSString *)storageLocationForAnimationFrames:(RedditPost *)entry
{
	if ([self wasCurrentUserPost:entry])
	{
		NSString *outputDir = [self iOSRedditAPIdir];
		return [outputDir stringByAppendingPathComponent:
				[NSString stringWithFormat:@"%@.plist", entry.redditID]];
	}
	
	return [self storageLocationExpirableCacheAnimationFrames:entry];
}

+(NSString *)storageLocation:(RedditPost *)entry
{
	if ([self wasCurrentUserPost:entry])
	{
		NSString *outputDir = [self iOSRedditAPIdir];
		return [outputDir stringByAppendingPathComponent:
				[NSString stringWithFormat:@"%@.gif", entry.redditID]];
	}
	
	return [self storageLocationExpirableCache:entry];
}

+(NSString *)storageLocationForPreview:(RedditPost *)entry
{
	if ([self wasCurrentUserPost:entry])
	{
		NSString *outputDir = [self iOSRedditAPIdir];
		return [outputDir stringByAppendingPathComponent:
				[NSString stringWithFormat:@"%@_preview.png", entry.redditID]];
	}
	
	return [self storageLocationExpirableCachePreview:entry];
}

+(NSString *)storageLocationForOnlinePreview:(RedditPost *)entry
{
	NSString *outputDir = [self iOSRedditAPIdir];
	return [outputDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@_online_preview.png", entry.redditID]];
}

-(BOOL)hasModHash
{
	if (self.modHash && [self.modHash length]>0)
	{
		return YES;
	}
	return NO;
}

@synthesize user=_user;
-(NSString *)user
{
	if (!_user)
	{
		NSString *userDefaultValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"iOSRedditAPI_user"];
		
		if (userDefaultValue)
		{
			_user = [[NSString alloc] initWithString:userDefaultValue];
		}
	}
	
	return _user;
}
-(void)setUser:(NSString *)value
{
	_user = [[NSString alloc] initWithString:value];
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"iOSRedditAPI_user"];
}

@synthesize passwd=_passwd;
-(NSString *)passwd
{
	if (!_passwd)
	{
		NSString *userDefaultValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"iOSRedditAPI_passwd"];
		
		if (userDefaultValue)
		{
			_passwd = [[NSString alloc] initWithString:userDefaultValue];
		}
	}
	
	return _passwd;
}
-(void)setPasswd:(NSString *)value
{
	_passwd = [[NSString alloc] initWithString:value];
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"iOSRedditAPI_passwd"];
}

@synthesize modHash=_modHash;
-(NSString *)modHash
{
	if (!_modHash)
	{
		NSString *userDefaultValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"iOSRedditAPI_modHash"];
		
		if (userDefaultValue)
		{
			_modHash = [[NSString alloc] initWithString:userDefaultValue];
		}
	}
	
	return _modHash;
}
-(void)setModHash:(NSString *)value
{
	_modHash = [[NSString alloc] initWithString:value];
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"iOSRedditAPI_modHash"];
}

@synthesize loginCookie=_loginCookie;
-(NSString *)loginCookie
{
	if (!_loginCookie)
	{
		NSString *userDefaultValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"iOSRedditAPI_loginCookie"];
		
		if (userDefaultValue)
		{
			_loginCookie = [[NSString alloc] initWithString:userDefaultValue];
		}
	}
	
	return _loginCookie;
}
-(void)setLoginCookie:(NSString *)value
{
	_loginCookie = [[NSString alloc] initWithString:value];
	[[NSUserDefaults standardUserDefaults] setObject:value forKey:@"iOSRedditAPI_loginCookie"];
}

- (id)init
{
    self = [super init];
    if (self)
	{
		self.cachedRedditPosts = [NSMutableDictionary dictionary];
	}
    return self;
}

+(iOSRedditAPI *)shared
{
	static iOSRedditAPI *_shared = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_shared = [[iOSRedditAPI alloc] init];
	});
	
	return _shared;
}

-(NSDictionary *)payloadFromResponse:(NSData *)responseData
{
	NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
	if (response && [response isKindOfClass:[NSDictionary class]])
	{
		return response[@"json"];
	}
	return nil;
}

-(NSDictionary *)dataDictionaryFromResponse:(NSData *)responseData
{
	NSDictionary *payload = [self payloadFromResponse:responseData];
	if (payload && [payload isKindOfClass:[NSDictionary class]])
	{
		NSArray *errors = payload[@"errors"];
		
		if (!errors || [errors count]==0)
		{
			NSDictionary *data = payload[@"data"];
			if (data && [data isKindOfClass:[NSDictionary class]])
			{
				NSLog(@"responseData: %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
				return data;
			}
		}
	}
	NSLog(@"dataDictionaryFromResponse: parsing problem: \n\n%@\n\n", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
	return nil;
}

-(NSDictionary *)errorFromResponse:(NSData *)responseData
{
	NSDictionary *payload = [self payloadFromResponse:responseData];
	if (payload && [payload isKindOfClass:[NSDictionary class]])
	{
		NSArray *errors = payload[@"errors"];
		
		if (errors && [errors count]!=0)
		{
			NSArray *errorAttributes = [errors objectAtIndex:0];
			
			if (errorAttributes && [errorAttributes count]>2)
			{
				NSString *errorType = [errorAttributes objectAtIndex:0];
				NSString *errorMsg = [errorAttributes objectAtIndex:1];
				NSString *errorDomain = [errorAttributes objectAtIndex:2];
				
				return @{
							@"type": errorType,
							@"message": errorMsg,
							@"domain": errorDomain
						};
			}
		}
	}
	NSLog(@"errorsFromResponse: parsing problem: \n\n%@\n\n", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
	return nil;
}

-(NSString *)addParamForKey:(NSString *)key withValue:(NSString *)value toString:(NSString *)params
{
	if (!value)
	{
		return params;
	}
	
	return [params stringByAppendingFormat:@"&%@=%@", key, [value stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
}

-(NSURLRequest *)requestWithURL:(NSURL *)url andPost:(NSString *)postString
{
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
		
	[request setCachePolicy:NSURLCacheStorageNotAllowed];
	[request setValue:@"creeper v1.0 by /u/dpedley" forHTTPHeaderField:@"User-Agent"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[request setHTTPMethod:@"POST"];
	[request setHTTPBody:[postString dataUsingEncoding:NSASCIIStringEncoding]];
	
	NSLog(@"requestWithURL: %@\n%@\n%@\n\n", request.URL, postString, request.allHTTPHeaderFields);
	return request;
}

-(void)login:(NSString *)user passwd:(NSString *)passwd success:(void (^)(BOOL success))completionBlock
{
	self.user = user;
	self.passwd = passwd;
	[self establishConnection:completionBlock];
}

-(void)submitLink:(NSString *)link captchaGuess:(NSString *)guess iden:(NSString *)iden subreddit:(NSString *)sr title:(NSString *)title captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock
{
	NSURL *submit = [NSURL URLWithString:@"https://ssl.reddit.com/api/submit"];
	/*
	 captcha	the user's response to the CAPTCHA challenge
	 extension	extension used for redirects
	 iden	the identifier of the CAPTCHA challenge
	 kind	one of (link, self)
	 resubmit	boolean value
	 save	boolean value
	 sendreplies	boolean value
	 sr	name of a subreddit
	 text	raw markdown text
	 then	one of (tb, comments)
	 title	title of the submission. up to 300 characters long
	 uh	a valid modhash
	 url*/
	NSString *postBody = @"api_type=json&kind=link&save=YES"; //&=%@&=%@&=%@&url=%@"
	postBody = [self addParamForKey:@"uh" withValue:self.modHash toString:postBody];
	postBody = [self addParamForKey:@"captcha" withValue:guess toString:postBody];
	postBody = [self addParamForKey:@"iden" withValue:iden toString:postBody];
	postBody = [self addParamForKey:@"title" withValue:title toString:postBody];
	postBody = [self addParamForKey:@"sr" withValue:sr toString:postBody];
	postBody = [self addParamForKey:@"url" withValue:link toString:postBody];
	
	NSURLRequest *request = [self requestWithURL:submit andPost:postBody];
	
	self.engine = [iOSRedditWebEngine engineWithDataBlock:^(NSData *data, NSError *error) {
		__block NSDictionary *submitData = [self dataDictionaryFromResponse:data];
		if (submitData)
		{
			/*
			 {
			 id = 1aechj;
			 name = "t3_1aechj";
			 url = "https://ssl.reddit.com/r/creeperapp/comments/1aechj/wood_stove_diy/";
			 }
			 */
			DLog(@"submitData: %@", submitData);
			
			// In addition load this into our reddit cache
			[[iOSRedditAPI shared] loadCurrentDataForRedditPostID:[submitData objectForKey:@"id"] completion:^(NSDictionary *postDictionary, BOOL cached) {
				DLog(@"the post: %@", postDictionary);
				
				if (!cached)
				{
					[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
						RedditPost *newPost = nil;
						if (postDictionary)
						{
							newPost = [RedditPost withDictionary:postDictionary inContext:localContext];
						}
						else
						{
							NSMutableDictionary *wAuth = [NSMutableDictionary dictionaryWithDictionary:submitData];
							[wAuth setObject:self.user forKey:@"author"];
							newPost = [RedditPost withDictionary:wAuth inContext:localContext];
						}
						newPost.validationString = [ExternalServices createVerificationHash:newPost.imgurLink];
					} completion:^(BOOL success, NSError *error) {
						RedditPost *savedPost = [RedditPost findFirstByAttribute:@"redditID" withValue:[submitData objectForKey:@"id"]];
						completionBlock(YES, savedPost);
					}];
				}
				else
				{
					RedditPost *savedPost = [RedditPost findFirstByAttribute:@"redditID" withValue:[submitData objectForKey:@"id"]];
					completionBlock(YES, savedPost);
				}
				return;
			}];

		}
		else
		{
			NSDictionary *errorDictionary = [self errorFromResponse:data];
			
			if (errorDictionary)
			{
				if ([errorDictionary[@"type"] isEqualToString:@"BAD_CAPTCHA"])
				{
					// {"json": {"captcha": "9eAaxlWxOlOP3eKNHgsR46nknuseTEsR", "errors": [["BAD_CAPTCHA", "care to try these again?", "captcha"]]}}
					NSDictionary *payload = [self payloadFromResponse:data];
					NSString *newIden = [payload objectForKey:@"captcha"];
					
					if (newIden)
					{
						[self submitLink:link toSubreddit:sr withTitle:title iden:newIden captchaVC:vc submitted:completionBlock];
						return;
					}
				}
			}
			
			completionBlock(NO, nil);
		}
	}];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.engine startImmediately:YES];
	if (!conn)
	{
		NSLog(@"Couldn't make connection: %@", request.URL);
	}
}

-(void)submitLink:(NSString *)link toSubreddit:(NSString *)sr withTitle:(NSString *)title iden:(NSString *)iden captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock
{
	iOSRedditCaptcha *captcha = [iOSRedditCaptcha captchaWithIden:iden responseBlock:^(NSString *guess) {
		
		[self establishConnection:^(BOOL connectionEstablished) {
			[vc dismissViewControllerAnimated:YES completion:^{
				if (connectionEstablished)
				{
					[self submitLink:link captchaGuess:guess iden:iden subreddit:sr title:title captchaVC:vc submitted:completionBlock];
				}
			}];
		}];
	}];
	
	if (captcha)
	{
		[vc presentViewController:captcha animated:YES completion:^{
		}];
	}
}

-(void)captcha:(void(^)(NSString *iden))captchaBlock
{
	NSURL *captcha = [NSURL URLWithString:@"https://ssl.reddit.com/api/new_captcha"];
	
	NSURLRequest *request = [self requestWithURL:captcha andPost:@"api_type=json"];
	
	self.engine = [iOSRedditWebEngine engineWithDataBlock:^(NSData *data, NSError *error) {
		NSDictionary *captchaData = [self dataDictionaryFromResponse:data];
		if (captchaData)
		{
			__block NSString *iden = captchaData[@"iden"];
			
			if (iden)
			{
				captchaBlock(iden);
				return;
			}
		}
		captchaBlock(nil);
	}];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.engine startImmediately:YES];
	if (!conn)
	{
		NSLog(@"Couldn't make connection: %@", request.URL);
		captchaBlock(nil);
	}
}

-(void)submitLink:(NSString *)link toSubreddit:(NSString *)sr withTitle:(NSString *)title captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock
{
	__block iOSRedditLogin *loginVC = [iOSRedditLogin withResponseBlock:^(BOOL success) {
		iOSRedditDismissedBlock dismissedBlock = ^{
			if (success)
			{
				[self captcha:^(NSString *iden) {
					if (iden)
					{
						[self submitLink:link toSubreddit:sr withTitle:title iden:iden captchaVC:vc submitted:completionBlock];
						return;
					}
					completionBlock(NO, nil);
				}];
			}
			else
			{
				completionBlock(NO, nil);
			}
		};
		if (loginVC)
		{
			[vc dismissViewControllerAnimated:YES completion:dismissedBlock];
		}
		else
		{
			dismissedBlock();
		}
	}];
	
	if (loginVC)
	{
		[vc presentViewController:loginVC animated:YES completion:^{
			if (self.user)
			{
				loginVC.user.text = self.user;
			}
			
			if (self.passwd)
			{
				loginVC.passwd.text = self.passwd;
			}
		}];
	}
}

-(void)internalDeleteByName:(NSString *)theRedditName parentVC:(UIViewController *)vc deleted:(iOSRedditGenericCompletion)completionBlock
{
	NSURL *del = [NSURL URLWithString:@"https://ssl.reddit.com/api/del"];
	/*
	 id fullname of a thing created by the user
	 uh	a valid modhash
	 */
	NSString *postBody = @"api_type=json"; //&=%@&=%@&=%@&url=%@"
	postBody = [self addParamForKey:@"uh" withValue:self.modHash toString:postBody];
	postBody = [self addParamForKey:@"id" withValue:theRedditName toString:postBody];
	
	NSURLRequest *request = [self requestWithURL:del andPost:postBody];
	
	self.engine = [iOSRedditWebEngine engineWithDataBlock:^(NSData *data, NSError *error) {
		if (!error)
		{
			completionBlock(YES);
		}
		else
		{
			completionBlock(NO);
		}
	}];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.engine startImmediately:YES];
	if (!conn)
	{
		NSLog(@"Couldn't make connection: %@", request.URL);
		completionBlock(NO);
	}
}

-(void)deleteByName:(NSString *)theRedditName parentVC:(UIViewController *)vc deleted:(iOSRedditGenericCompletion)completionBlock
{
	__block iOSRedditLogin *loginVC = [iOSRedditLogin withResponseBlock:^(BOOL success) {
		iOSRedditDismissedBlock dismissedBlock = ^{
			if (success)
			{
				[self internalDeleteByName:theRedditName parentVC:vc deleted:completionBlock];
				return;
			}
			else
			{
				completionBlock(NO);
			}
		};
		if (loginVC)
		{
			[vc dismissViewControllerAnimated:YES completion:dismissedBlock];
		}
		else
		{
			dismissedBlock();
		}
	}];
	
	if (loginVC)
	{
		[vc presentViewController:loginVC animated:YES completion:^{
			if (self.user)
			{
				loginVC.user.text = self.user;
			}
			
			if (self.passwd)
			{
				loginVC.passwd.text = self.passwd;
			}
		}];
	}
}

-(void)internalAddCommentTo:(NSString *)theRedditName comment:(NSString *)comment parentVC:(UIViewController *)vc complete:(iOSRedditGenericCompletion)completionBlock
{
	NSURL *commURL = [NSURL URLWithString:@"https://ssl.reddit.com/api/comment"];
	/*
	 api_type - the string json
	 text - raw markdown text
	 thing_id - fullname of parent thing
	 uh - a valid modhash
	 */
	NSString *postBody = @"api_type=json"; //&=%@&=%@&=%@&url=%@"
	postBody = [self addParamForKey:@"uh" withValue:self.modHash toString:postBody];
	postBody = [self addParamForKey:@"thing_id" withValue:theRedditName toString:postBody];
	postBody = [self addParamForKey:@"text" withValue:comment toString:postBody];
	
	NSURLRequest *request = [self requestWithURL:commURL andPost:postBody];
	
	self.engine = [iOSRedditWebEngine engineWithDataBlock:^(NSData *data, NSError *error) {
		if (!error)
		{
			completionBlock(YES);
		}
		else
		{
			completionBlock(NO);
		}
	}];
	NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.engine startImmediately:YES];
	if (!conn)
	{
		NSLog(@"Couldn't make connection: %@", request.URL);
		completionBlock(NO);
	}
}

-(void)addCommentTo:(NSString *)theRedditName comment:(NSString *)comment parentVC:(UIViewController *)vc complete:(iOSRedditGenericCompletion)completionBlock
{
	__block iOSRedditLogin *loginVC = [iOSRedditLogin withResponseBlock:^(BOOL success) {
		iOSRedditDismissedBlock dismissedBlock = ^{
			if (success)
			{
				[self internalAddCommentTo:theRedditName comment:comment parentVC:vc complete:completionBlock];
				return;
			}
			else
			{
				completionBlock(NO);
			}
		};
		if (loginVC)
		{
			[vc dismissViewControllerAnimated:YES completion:dismissedBlock];
		}
		else
		{
			dismissedBlock();
		}
	}];
	
	if (loginVC)
	{
		[vc presentViewController:loginVC animated:YES completion:^{
			if (self.user)
			{
				loginVC.user.text = self.user;
			}
			
			if (self.passwd)
			{
				loginVC.passwd.text = self.passwd;
			}
		}];
	}
}

-(NSString *)createValidateComment:(RedditPost *)post
{
	// This animation was created using [CREEPER](http://itunes.apple.com/us/app/creeper/id615185807 "29394831c5cc8d4b5e6aa31c8a8d8b86499a1f79")

	return [NSString stringWithFormat:@"This animation was created using [CREEPER](http://itunes.apple.com/us/app/creeper/id615185807 \"%@\")", [ExternalServices createVerificationHash:post.imgurLink]];
}

-(NSString *)parseValidateComment:(NSString *)commentBody
{
	if (!commentBody)
	{
		return nil;
	}
	
	// This animation was created using [CREEPER](http://itunes.apple.com/us/app/creeper/id615185807 "29394831c5cc8d4b5e6aa31c8a8d8b86499a1f79")
	
	NSString *beforeValidation = @"This animation was created using [CREEPER](http://itunes.apple.com/us/app/creeper/id615185807 \"";
	NSString *afterValidation = @"\")";

	NSRange startRange = [commentBody rangeOfString:beforeValidation];
	
	if (startRange.location==NSNotFound)
	{
		return nil;
	}
	
	NSRange endRange = [commentBody rangeOfString:afterValidation options:NSBackwardsSearch];
	
	if (endRange.location==NSNotFound)
	{
		return nil;
	}
	
	return [commentBody substringWithRange:NSMakeRange(startRange.location + startRange.length, endRange.location - (startRange.location + startRange.length))];
}


-(void)addPostValidation:(RedditPost *)post parentVC:(UIViewController *)vc complete:(iOSRedditGenericCompletion)completionBlock
{
	[self addCommentTo:post.redditName comment:[self createValidateComment:post] parentVC:vc complete:completionBlock];
}


-(void)establishConnection:(void (^)(BOOL connectionEstablished))connectionBlock
{
	if (!self.modHash)
	{
		NSURL *login = [NSURL URLWithString:@"https://ssl.reddit.com/api/login"];
		NSString *postBody = @"api_type=json&rem=on";
		postBody = [self addParamForKey:@"user" withValue:self.user toString:postBody];
		postBody = [self addParamForKey:@"passwd" withValue:self.passwd toString:postBody];
		NSURLRequest *request = [self requestWithURL:login andPost:postBody];
		
		self.engine = [iOSRedditWebEngine engineWithDataBlock:^(NSData *data, NSError *error) {
			NSDictionary *loginData = [self dataDictionaryFromResponse:data];
			if (loginData)
			{
				self.modHash = loginData[@"modhash"];
				self.loginCookie = loginData[@"cookie"];
				connectionBlock(YES);
				return;
			}
			connectionBlock(NO);
		}];
		NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self.engine startImmediately:YES];
		if (!conn)
		{
			NSLog(@"Couldn't make connection: %@", request.URL);
		}
	}
	else
	{
		connectionBlock(YES);
	}
}

#pragma mark - loading reddit posts

-(void)loadCurrentDataForRedditPostID:(NSString *)id completion:(iOSRedditLoadPostData)completion
{
	NSString *urlKey = [NSString stringWithFormat:@"http://api.reddit.com/%@", id];
	
	NSDictionary *cachedPostDictionary = [self.cachedRedditPosts objectForKey:urlKey];
	
	if (cachedPostDictionary)
	{
		NSDate *originalDate = [cachedPostDictionary objectForKey:@"timestamp"];
		
		if (originalDate && [originalDate isKindOfClass:[NSDictionary class]] && [[NSDate date] timeIntervalSinceDate:originalDate] < REDDIT_POST_TTL)
		{
			DLog(@"Returning cached post.");
			completion(cachedPostDictionary, YES);
			return;
		}
		[self.cachedRedditPosts removeObjectForKey:urlKey];
	}
	
	dispatch_queue_t urlQueue = dispatch_queue_create("iOSRedditAPI_loadCurrentDataForRedditPostID", 0);
	dispatch_async(urlQueue, ^{
		NSURL *redditURL = [NSURL URLWithString:urlKey];
		NSData *jsonData = [NSData dataWithContentsOfURL:redditURL];
		
		if (jsonData)
		{
			NSArray *items = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
			
			if ([items isKindOfClass:[NSArray class]] && [items count]>0)
			{
				NSDictionary *tlItem = [items objectAtIndex:0];
				if ([tlItem isKindOfClass:[NSDictionary class]])
				{
					NSDictionary *tlData = [tlItem objectForKey:@"data"];
					if ([tlData isKindOfClass:[NSDictionary class]])
					{
						NSArray *slChildren = [tlData objectForKey:@"children"];
						
						if ([slChildren isKindOfClass:[NSArray class]] && [slChildren count]>0)
						{
							NSDictionary *innerItem = [slChildren objectAtIndex:0];
							if ([innerItem isKindOfClass:[NSDictionary class]])
							{
								NSDictionary *postDict = [innerItem objectForKey:@"data"];
								
								if (postDict && [postDict isKindOfClass:[NSDictionary class]])
								{
									NSMutableDictionary *postCache = [postDict mutableCopy];
									[postCache setObject:[NSDate date] forKey:@"timestamp"];
									[self.cachedRedditPosts setObject:postCache forKey:urlKey];
									completion(postCache, NO);
									return;
								}
							}
						}
					}
				}
			}
		}
		completion(nil, NO);
	});
}

-(void)validatePost:(RedditPost *)aPost
{
	dispatch_queue_t urlQueue = dispatch_queue_create("iOSRedditAPI_validatePost", 0);
	dispatch_async(urlQueue, ^{
		NSURL *redditURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.reddit.com/comments/%@.json", aPost.redditID]];
		NSData *jsonData = [NSData dataWithContentsOfURL:redditURL];
		
		if (jsonData)
		{
			NSDictionary *postArray = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
			if ([postArray isKindOfClass:[NSArray class]])
			{
				for (NSDictionary *srDictionary in postArray)
				{
					NSDictionary *tlData = [srDictionary objectForKey:@"data"];
					if ([tlData isKindOfClass:[NSDictionary class]])
					{
						NSArray *slChildren = [tlData objectForKey:@"children"];
						
						if ([slChildren isKindOfClass:[NSArray class]] && [slChildren count]>0)
						{
							for (int i=0; i<[slChildren count]; i++)
							{
								NSDictionary *innerItem = [slChildren objectAtIndex:i];
								if ([innerItem isKindOfClass:[NSDictionary class]])
								{
									NSString *redditKind = [innerItem objectForKey:@"kind"];
									
									if (redditKind && [redditKind isEqualToString:@"t1"])
									{
										NSDictionary *postDict = [innerItem objectForKey:@"data"];
										if ([postDict isKindOfClass:[NSDictionary class]])
										{
											NSString *bodyMarkDown = [postDict objectForKey:@"body"];
											NSString *validationString = [self parseValidateComment:bodyMarkDown];
											
											if (validationString && [validationString isEqualToString:[ExternalServices createVerificationHash:aPost.imgurLink]])
											{
												[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
													RedditPost *localPost = [RedditPost findFirstByAttribute:@"redditID" withValue:aPost.redditID inContext:localContext];
													localPost.validationString = validationString;
												} completion:^(BOOL success, NSError *error) {
													
												}];
												return;
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	});
}

-(void)loadSubreddit:(NSString *)subreddit completion:(iOSRedditSubredditPosts)completion
{
	dispatch_queue_t urlQueue = dispatch_queue_create("iOSRedditAPI_loadSubreddit", 0);
	dispatch_async(urlQueue, ^{
		NSURL *redditURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://api.reddit.com/r/%@", subreddit]];
		NSData *jsonData = [NSData dataWithContentsOfURL:redditURL];
		
		if (jsonData)
		{
			NSDictionary *srDictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
			
			if ([srDictionary isKindOfClass:[NSDictionary class]])
			{
				NSDictionary *tlData = [srDictionary objectForKey:@"data"];
				if ([tlData isKindOfClass:[NSDictionary class]])
				{
					NSArray *slChildren = [tlData objectForKey:@"children"];
					
					if ([slChildren isKindOfClass:[NSArray class]] && [slChildren count]>0)
					{
						__block NSMutableArray *retPosts = [NSMutableArray array];
						[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
							
							NSPredicate *possiblyDelete = [NSPredicate predicateWithFormat:@"self.hotOrder >= %d", 0];
							
							NSArray *previousPosts = [RedditPost MR_findAllWithPredicate:possiblyDelete inContext:localContext];
							
							NSMutableDictionary *postsByID = [NSMutableDictionary dictionary];
							
							for (RedditPost *post in previousPosts)
							{
								post.hotOrder = [NSNumber numberWithInt:-1];
								[postsByID setObject:post forKey:post.redditID];
							}
							
							previousPosts = nil;
							
							for (int i=0; i<[slChildren count]; i++)
							{
								NSDictionary *innerItem = [slChildren objectAtIndex:i];
								if ([innerItem isKindOfClass:[NSDictionary class]])
								{
									NSString *redditKind = [innerItem objectForKey:@"kind"];
									
									if (redditKind && [redditKind isEqualToString:@"t3"])
									{
										NSDictionary *postDict = [innerItem objectForKey:@"data"];
										if ([postDict isKindOfClass:[NSDictionary class]])
										{
											RedditPost *redditPost = [RedditPost withDictionary:postDict inContext:localContext];
											[postsByID removeObjectForKey:redditPost.redditID];
											redditPost.hotOrder = [NSNumber numberWithInt:i];
											if ([redditPost.domain isEqualToString:@"i.imgur.com"] && !redditPost.nsfw)
											{
												[retPosts addObject:redditPost];
											}
										}
									}
								}
							}
							
							NSArray *allUnclaimedPosts = [postsByID allValues];
							
							for (RedditPost *post in allUnclaimedPosts)
							{
								[post deleteInContext:localContext];
							}
							
							// Next we validate any posts that aren't already validated.
							for (RedditPost *aPost in retPosts)
							{
								if (!aPost.validationString || ![aPost.validationString isEqualToString:[ExternalServices createVerificationHash:aPost.imgurLink]])
								{
									[self validatePost:aPost];
								}
							}
							
						} completion:^(BOOL success, NSError *error) {
							completion(retPosts);
						}];						
						return;
					}
				}
			}
		}
		completion(nil);
	});
}

@end

#pragma mark -

@implementation iOSRedditWebEngine

+(id)engineWithDataBlock:(iOSRedditWebEngineDataBlock)completion
{
	iOSRedditWebEngine *theEngine = [[iOSRedditWebEngine alloc] init];
	theEngine.dataBlock = completion;
	theEngine.delegate = theEngine;
	return theEngine;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSLog(@"loading.... %d %@", navigationType, request.URL);
	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
	
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{

}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
	self.pageData = [NSMutableData data];
	
	return request;
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSLog(@"conn-response: \n%@\n\n%@\n", [(NSHTTPURLResponse *)response allHeaderFields], [[NSString alloc] initWithData:self.pageData encoding:NSUTF8StringEncoding]);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.pageData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
//	NSLog(@"We're done, close and complete.");
	
	if (self.dataBlock)
	{
		self.dataBlock(self.pageData, nil);
	}
}

@end

