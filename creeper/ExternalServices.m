//
//  ExternalServices.m
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

#import "ExternalServices.h"
#import "iOSRedditAPI.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#ifdef CRASHLYTICS_API_KEY
#import <Crashlytics/Crashlytics.h>
#endif

@implementation ExternalServices

static NSData *_cryptoKey = nil;

+(NSData *)cryptoKey
{
	if (!_cryptoKey)
	{
		NSMutableData *theData = [NSMutableData dataWithLength:256];
		
		_cryptoKey = [[NSData alloc] initWithData:theData];
	}
	
	return _cryptoKey;
}

+(NSString*)createVerificationHash:(NSString*)inputURL
{
	NSData *data = [inputURL dataUsingEncoding:NSUTF8StringEncoding];
	NSData *key = [self cryptoKey];
	uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [key bytes], [key length], [data bytes], [data length], &(digest[0]));
	NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
	for (int i=0; i < CC_SHA1_DIGEST_LENGTH; i++)
	{
		[output appendFormat:@"%02x", digest[i]];
	}
	
	return output;
}

+(void)appServiceStartup
{
#ifdef CRASHLYTICS_API_KEY
    [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
#endif

	
}

+(void)addBasicAuthorization:(NSMutableURLRequest *)request
{
	
}


@end
