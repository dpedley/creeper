//
//  iOSRedditCaptcha.m
//  creeper
//
//  Created by Douglas Pedley on 3/15/13.
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

#import "iOSRedditCaptcha.h"

@interface iOSRedditCaptcha ()

@property (nonatomic, strong) NSString *iden;
@property (nonatomic, strong) IBOutlet UIImageView *captcha;
@property (nonatomic, strong) IBOutlet UITextField *captchaGuess;

@property (nonatomic, strong) iOSRedditCaptchaResponse responseBlock;

@end

@implementation iOSRedditCaptcha

+(id)captchaWithIden:(NSString *)theIden responseBlock:(iOSRedditCaptchaResponse)aResponseBlock
{
	iOSRedditCaptcha *vc = [[iOSRedditCaptcha alloc] initWithNibName:@"iOSRedditCaptcha" bundle:[NSBundle mainBundle]];
	vc.responseBlock = aResponseBlock;
	vc.iden = theIden;
	return vc;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	
	if (self.iden)
	{
		NSURL *captchaURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.reddit.com/captcha/%@.png", self.iden]];
		self.captcha.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:captchaURL]];
	}
	
	[self.captchaGuess becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (self.responseBlock)
	{
		self.responseBlock(self.captchaGuess.text);

	}
	return YES;
}

@end
