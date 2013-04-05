//
//  iOSRedditLogin.m
//  creeper
//
//  Created by Douglas Pedley on 3/16/13.
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


#import "iOSRedditLogin.h"
#import "iOSRedditAPI.h"

@interface iOSRedditLogin ()

@property (nonatomic, copy) iOSRedditLoginResponse responseBlock;
@property (nonatomic, strong) IBOutlet UILabel *errorLabel;

-(IBAction)login:(id)sender;

@end

@implementation iOSRedditLogin

+(id)withResponseBlock:(iOSRedditLoginResponse)aResponseBlock
{
	if ([[iOSRedditAPI shared] hasModHash])
	{
		aResponseBlock(YES);
		return nil;
	}

	iOSRedditLogin *vc = [[iOSRedditLogin alloc] initWithNibName:@"iOSRedditLogin" bundle:[NSBundle mainBundle]];
	vc.responseBlock = aResponseBlock;
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
	[self.errorLabel setHidden:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)login:(id)sender
{
	[[iOSRedditAPI shared] login:self.user.text passwd:self.passwd.text success:^(BOOL success) {
		if (success)
		{
			if (self.responseBlock)
			{
				self.responseBlock(YES);
			}
		}
		else
		{
			[self.errorLabel setHidden:NO];
		}
	}];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self login:textField];
	return YES;
}

@end
