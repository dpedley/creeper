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

typedef void (^iOSRedditWebEngineDataBlock)(NSData *data, NSError *error);
typedef void (^iOSRedditDismissedBlock)();

@interface iOSRedditWebEngine : UIWebView <UIWebViewDelegate, NSURLConnectionDelegate>

@property (nonatomic, strong) NSMutableData *pageData;
@property (nonatomic, copy) iOSRedditWebEngineDataBlock dataBlock;

+(id)engineWithDataBlock:(iOSRedditWebEngineDataBlock)completion;

@end

@interface iOSRedditAPI ()

@property (nonatomic, strong) iOSRedditWebEngine *engine;
@property (nonatomic, strong) NSString *modHash;
@property (nonatomic, strong) NSString *loginCookie;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *passwd;

-(void)establishConnection:(void (^)(BOOL connectionEstablished))connectionBlock;
-(void)submitLink:(NSString *)link toSubreddit:(NSString *)sr withTitle:(NSString *)title iden:(NSString *)iden captchaVC:(UIViewController *)vc submitted:(iOSRedditPostCompletion)completionBlock;

@end
@implementation iOSRedditAPI

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
		NSDictionary *submitData = [self dataDictionaryFromResponse:data];
		if (submitData)
		{
			/*
			 {
			 id = 1aechj;
			 name = "t3_1aechj";
			 url = "https://ssl.reddit.com/r/creeperapp/comments/1aechj/wood_stove_diy/";
			 }
			 */
			NSLog(@"submitData: %@", submitData);
			
			RedditPost *newPost = [RedditPost addNew];
			newPost.redditID = [submitData objectForKey:@"id"];
			newPost.redditURL = [submitData objectForKey:@"url"];
			newPost.postName = [submitData objectForKey:@"name"];
			[RedditPost save];
			
			completionBlock(YES, newPost);
			return;
		}
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
		
		NSLog(@"captcha: %@", guess);
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

@end

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
//	NSLog(@"conn-response: \n%@\n\n%@\n", [(NSHTTPURLResponse *)response allHeaderFields], [[NSString alloc] initWithData:self.pageData encoding:NSUTF8StringEncoding]);
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.pageData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSLog(@"We're done, close and complete.");
	
	if (self.dataBlock)
	{
		self.dataBlock(self.pageData, nil);
	}
}

@end
