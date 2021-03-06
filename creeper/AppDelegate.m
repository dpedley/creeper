//
//  AppDelegate.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
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

#import "AppDelegate.h"
#import "AnimationListController.h"
#import "FeedItem.h"
#import "CreeperSHKConfigurator.h"
#import "SHK.h"
#import "SHKConfiguration.h"
#import <Crashlytics/Crashlytics.h>
#import "ExternalServices.h"

NSString *creeperPrefix = @"ccf8837e-83d0-11e2-b939-f23c91aec05e"; // Note this doubles as the app store SKU

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
	UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
	AnimationListController *controller = (AnimationListController *)navigationController.topViewController;
	
	[ExternalServices appServiceStartup];
	
	// Init mochi
	[Mochi settingsFromDictionary:@{ @"database" : @"creeper", @"model" : @"creeper" }];
	controller.managedObjectContext = [[Mochi mochiForClass:[FeedItem class]] managedObjectContext];
	
	CreeperSHKConfigurator *configurator = [[CreeperSHKConfigurator alloc] init];
	[SHKConfiguration sharedInstanceWithConfigurator:configurator];
	
	self.currentOrientationMask = UIInterfaceOrientationMaskAllButUpsideDown;

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

#pragma mark - Orientation stuff

+(void)lockOrientation
{
	AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	app.currentOrientationMask = (1 << [[UIApplication sharedApplication] statusBarOrientation]);
}

+(void)unlockOrientation
{
	AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	app.currentOrientationMask = UIInterfaceOrientationMaskAllButUpsideDown;
}


- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
	return self.currentOrientationMask;
}

@end
