//
//  SceneCapture.m
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

#import "SceneCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/CALayer.h>
#import "GifCreationManager.h"
#import "ImageInfo.h"
#import <objc/message.h>
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "AppDelegate.h"

static NSUInteger TWOMEGS = 2000000;
static NSTimeInterval frmDelay = 0.125;

#define RGB(r,g,b) [UIColor colorWithRed: ((double)r / 255.0) green: ((double)g / 255.0) blue: ((double)b / 255.0) alpha:1.0]
static int SceneCapture_ClearAlert = 404;
static int SceneCapture_RotationAlert = 104;

@interface SceneCapture ()

@property (nonatomic, strong) IBOutlet UIView *screenShotView;
@property (nonatomic, strong) IBOutlet UIProgressView *animationProgress;
@property (nonatomic, strong) IBOutlet UILongPressGestureRecognizer *longPress;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *trashButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *frameDisplay;
@property (nonatomic, assign) BOOL animationActive;
@property (nonatomic, assign) int previewFrameCount;
@property (nonatomic, strong) NSString *encoderID;
@property (nonatomic, strong) UIColor *goColor;
@property (nonatomic, strong) UIColor *stopColor;
@property (nonatomic, assign) BOOL isShowingLandscapeView;

@property (nonatomic, readonly) UIView *orientScreenShotView;
@property (nonatomic, readonly) UIProgressView *orientAnimationProgress;
@property (nonatomic, readonly) UILongPressGestureRecognizer *orientLongPress;
@property (nonatomic, readonly) UIBarButtonItem *orientDoneButton;
@property (nonatomic, readonly) UIBarButtonItem *orientTrashButton;
@property (nonatomic, readonly) UIBarButtonItem *orientFrameDisplay;

-(IBAction)recordActionStateChange:(id)sender;
-(IBAction)clearRecordingAction:(id)sender;
-(IBAction)frameAdvanceAction:(id)sender;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

-(void)addGifFrame:(UIImage *)img;

@end

@implementation SceneCapture

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"LandscapeCamera"])
	{
        LandscapeSceneCapture *lc = [segue destinationViewController];
		lc.sceneCapture = self;
    }
}

#pragma mark - Utilities

-(void)updateFrameDisplay:(NSNumber *)currentSize
{
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(updateFrameDisplay:) withObject:currentSize waitUntilDone:NO];
		return;
	}
	
	if (self.frameCount==0)
	{
		[self.orientDoneButton setEnabled:NO];
		[self.orientTrashButton setEnabled:NO];
	}
	else
	{
		[self.orientDoneButton setEnabled:YES];
		[self.orientTrashButton setEnabled:YES];
	}
	
	[self.orientFrameDisplay setTitle:[NSString stringWithFormat:@"%d", self.frameCount]];
	if ([currentSize intValue] < TWOMEGS)
	{
		[self.orientFrameDisplay setEnabled:YES];
		[self.orientFrameDisplay setTintColor:self.goColor];
	}
	else
	{
		[self.orientFrameDisplay setEnabled:NO];
		[self.orientFrameDisplay setTintColor:self.stopColor];
	}
}

-(void)updateProgress:(NSNumber *)currentSize
{
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(updateProgress:) withObject:currentSize waitUntilDone:NO];
		return;
	}
	
	[self.orientAnimationProgress setProgress: ( [currentSize doubleValue] / (double)TWOMEGS ) animated:NO];
}

- (void)setupCaptureSession
{
    NSError *error = nil;
	
    @synchronized(self)
    {
        if (self.previewLayer)
        {
            [self.previewLayer removeFromSuperlayer];
            self.previewLayer = nil;
        }
        
        if (self.session)
        {
            [self.session stopRunning];
            self.session = nil;
        }
        
        [self updateFrameDisplay:[NSNumber numberWithInt:0]];
        
        // Create the session
        self.session = [[AVCaptureSession alloc] init];

		self.session.sessionPreset = AVCaptureSessionPresetLow;
        
        // Find a suitable AVCaptureDevice
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        if (device)
        {
            // Create a device input with the device and add it to the session.
            AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
            if (error)
            {
                // Handling the error appropriately.
                NSLog(@"Input error: %@", error);
                [SVProgressHUD dismiss];
                return;
            }
            
            if ([self.session canAddInput:input])
            {
                [self.session addInput:input];
            }
            else
            {
                DLog(@"Couldn't add input");
                [SVProgressHUD dismiss];
                return;
            }
            
            // Add Audio Input
    //		DLog(@"Adding audio input");
    //		AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //		NSError *error = nil;
    //		AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
    //		if (audioInput)
    //		{
    //			[CaptureSession addInput:audioInput];
    //		}
            
            
            // Create a VideoDataOutput and add it to the session
            AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
            [self.session addOutput:output];
            
            // Configure your output.
            dispatch_queue_t queue = dispatch_queue_create("captureQueue", NULL);
            [output setSampleBufferDelegate:self queue:queue];
            
            // Specify the pixel format
            output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                                               forKey:(id)kCVPixelBufferPixelFormatTypeKey];
            
            
            AVCaptureConnection *conn = [output connectionWithMediaType:AVMediaTypeVideo];
            
            if (conn.isVideoMinFrameDurationSupported)
                conn.videoMinFrameDuration = CMTimeMake(1, 8);
            if (conn.isVideoMaxFrameDurationSupported)
                conn.videoMaxFrameDuration = CMTimeMake(1, 8);
            
            switch (self.interfaceOrientation)
            {
                case UIDeviceOrientationPortrait:
                    conn.videoOrientation = AVCaptureVideoOrientationPortrait;
                    break;
                    
                case UIDeviceOrientationLandscapeRight:
                    conn.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
                    break;
                    
                case UIDeviceOrientationLandscapeLeft:
                    conn.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                    break;
                    
                default:
                    conn.videoOrientation = AVCaptureVideoOrientationPortrait;
                    break;
            }
            
            // Start the session running to start the flow of data
            [self.session startRunning];
            
            // create a preview layer to show the output from the camera
            UIView *ss = self.orientScreenShotView;
            CGRect frm = ss.bounds;
            ss.frame = frm;
            self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
            [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            self.previewLayer.frame = CGRectMake(0, 0, frm.size.width, frm.size.height);
            
            AVCaptureConnection *previewLayerConnection=self.previewLayer.connection;
            if ([previewLayerConnection isVideoOrientationSupported])
            {
                [previewLayerConnection setVideoOrientation:conn.videoOrientation];
            }
            [ss.layer addSublayer:self.previewLayer];
        }
        [SVProgressHUD popActivity];
    }
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
	
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
	
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
	
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
												 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
	
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
	
    // Release the Quartz image
    CGImageRelease(quartzImage);
	
    return (image);
}

-(void)createInitialFeedItem
{
	if (![NSThread mainThread])
	{
		[self performSelectorOnMainThread:@selector(createInitialFeedItem) withObject:nil waitUntilDone:YES];
		return;
	}
	FeedItem *newItem = [FeedItem addNew];
	newItem.timestamp = [NSDate date];
	newItem.encoderID = self.encoderID;
	newItem.feedItemType = FeedItemType_Encoding;
	[FeedItem save];
}

-(void)addGifFrame:(UIImage *)img
{
	GifCreationManager *gcm = [GifCreationManager sharedInstance];
	if (!self.encoderID)
	{		
		self.encoderID = [gcm createEncoderWithSize:img.size];
		if (!self.encoderID)
		{
			DLog(@"No encoder ID returned");
			return;
		}
		[self createInitialFeedItem];
	}

	[gcm addFrame:[GifQueueFrame withImage:img andDelay:frmDelay] toEncoder:self.encoderID];
}

#pragma mark - Actions

-(IBAction)recordActionStateChange:(id)sender
{
	switch (self.orientLongPress.state)
	{
		case UIGestureRecognizerStateBegan:
		{
			self.animationActive = YES;
		}
			break;
			
		case UIGestureRecognizerStateEnded:
		{
			self.animationActive = NO;
		}
			break;
			
		default:
			break;
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag==SceneCapture_ClearAlert)
	{
		if (buttonIndex==1)
		{
			if (self.encoderID)
			{
				[[GifCreationManager sharedInstance] clearEncoder:self.encoderID];
				self.encoderID = nil;
			}
			[self.orientAnimationProgress setProgress:0.0 animated:YES];
			self.frameCount = 0;
			[AppDelegate unlockOrientation];
			[self updateFrameDisplay:[NSNumber numberWithInt:0]];
		}
		else
		{
			// Cancelled
		}
	}
	else if (alertView.tag==SceneCapture_RotationAlert)
	{
		if (buttonIndex==1)
		{
			[[GifCreationManager sharedInstance] clearEncoder:self.encoderID];
			self.encoderID = nil;
			[self.orientAnimationProgress setProgress:0.0 animated:YES];
			self.frameCount = 0;
			[SVProgressHUD showWithStatus:@"Rotating video" maskType:SVProgressHUDMaskTypeGradient];
			[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
		}
		else
		{
			// Cancelled
		}
	}
	[alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
}

-(IBAction)clearRecordingAction:(id)sender
{
	if (self.frameCount>0)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure" message:@"Do you want to clear your recording?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = SceneCapture_ClearAlert;
		[alert show];
	}
}

-(IBAction)frameAdvanceAction:(id)sender
{
	self.animationActive = YES;
}

-(IBAction)doneAction:(id)sender
{
	[[GifCreationManager sharedInstance] closeEncoder:self.encoderID];
	[AppDelegate unlockOrientation];
	[self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Object lifecycle

/*
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (self.encoder || self.frameCount>0)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Camera Rotated" message:@"Do you want to clear your current recording and start with new orientation?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = SceneCapture_RotationAlert;
		[alert show];
	}
	else
	{
		[SVProgressHUD showWithStatus:@"Rotating video" maskType:SVProgressHUDMaskTypeGradient];
		[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
	}
}
*/

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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

	[self.animationProgress setProgress:0.0];
	self.animationActive = NO;
	self.goColor = RGB(27,188,43);
	self.stopColor = RGB(210,48,15);
	[self updateFrameDisplay:[NSNumber numberWithInt:0]];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	self.isShowingLandscapeView = NO;
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(orientationChanged:)
												 name:UIDeviceOrientationDidChangeNotification
											   object:nil];

	if (!self.session)
	{
		[SVProgressHUD showWithStatus:@"Setting up capture" maskType:SVProgressHUDMaskTypeGradient];
		[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Orientation

- (void)orientationChanged:(NSNotification *)notification
{
	if (self.frameCount>0)
	{
		return;
	}
	
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsLandscape(deviceOrientation) && !self.isShowingLandscapeView)
    {
        [self performSegueWithIdentifier:@"LandscapeCamera" sender:self];
        self.isShowingLandscapeView = YES;
		[SVProgressHUD showWithStatus:@"Rotating video" maskType:SVProgressHUDMaskTypeGradient];
		[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
        [self updateFrameDisplay:[NSNumber numberWithInt:0]];
		[self updateProgress:[NSNumber numberWithInt:0]];
    }
    else if (UIDeviceOrientationIsPortrait(deviceOrientation) && self.isShowingLandscapeView)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
        self.isShowingLandscapeView = NO;
		[SVProgressHUD showWithStatus:@"Rotating video" maskType:SVProgressHUDMaskTypeGradient];
		[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
        [self updateFrameDisplay:[NSNumber numberWithInt:0]];
		[self updateProgress:[NSNumber numberWithInt:0]];
    }
}

#pragma mark - AV Delegate

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
	self.previewFrameCount++;

	if (self.animationActive)
	{
		GifCreationQueue *queue = [GifCreationManager queueByID:self.encoderID];
		NSUInteger projectedStorageSize = queue.approxStorageFrameSize * (self.frameCount + 1);
		
		if ( projectedStorageSize < TWOMEGS )
		{
			NSLog(@"size: %d %d", projectedStorageSize, TWOMEGS);
			if (self.frameCount==0)
			{
				[AppDelegate lockOrientation];
			}
			self.frameCount++;

			// Create a UIImage from the sample buffer data
			UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
			
			[self addGifFrame:image];
			
			[self updateFrameDisplay:[NSNumber numberWithInt:projectedStorageSize]];
			[self updateProgress:[NSNumber numberWithInt:projectedStorageSize]];
			if ( (self.orientLongPress.state!=UIGestureRecognizerStateBegan) &&
				  (self.orientLongPress.state!=UIGestureRecognizerStateChanged) )
			{
				self.animationActive = NO;
			}
		}
	}
}

#pragma mark - Orientation Property Pass Through

-(id)orient:(SEL)propSelector
{
	if (self.isShowingLandscapeView)
	{
		if ([self.presentedViewController isKindOfClass:[LandscapeSceneCapture class]])
		{
			if ([self.presentedViewController respondsToSelector:propSelector])
			{
				return objc_msgSend(self.presentedViewController, propSelector);
			}
		}
	}
	
	if ([self respondsToSelector:propSelector])
	{
		return objc_msgSend(self, propSelector);
	}
	
	return NULL;
}

@dynamic orientScreenShotView;
-(UIView *)orientScreenShotView { return [self orient:@selector(screenShotView)]; }
@dynamic orientLongPress;
-(UILongPressGestureRecognizer *)orientLongPress { return [self orient:@selector(longPress)]; }
@dynamic orientAnimationProgress;
-(UIProgressView *)orientAnimationProgress { return [self orient:@selector(animationProgress)]; }
@dynamic orientDoneButton;
-(UIBarButtonItem *)orientDoneButton { return [self orient:@selector(doneButton)]; }
@dynamic orientTrashButton;
-(UIBarButtonItem *)orientTrashButton { return [self orient:@selector(trashButton)]; }
@dynamic orientFrameDisplay;
-(UIBarButtonItem *)orientFrameDisplay { return [self orient:@selector(frameDisplay)]; }

@end

#pragma mark -

@implementation LandscapeSceneCapture

-(void)viewDidLoad
{
    [super viewDidLoad];
	[self.animationProgress setProgress:self.sceneCapture.animationProgress.progress];
}

-(IBAction)recordActionStateChange:(id)sender { [self.sceneCapture recordActionStateChange:sender]; }
-(IBAction)clearRecordingAction:(id)sender    { [self.sceneCapture clearRecordingAction:sender]; }
-(IBAction)frameAdvanceAction:(id)sender      { [self.sceneCapture frameAdvanceAction:sender]; }
-(IBAction)doneAction:(id)sender
{
	[AppDelegate unlockOrientation];
	self.sceneCapture.isShowingLandscapeView = NO;
	[[GifCreationManager sharedInstance] closeEncoder:self.sceneCapture.encoderID];
	[self dismissViewControllerAnimated:YES completion:^{
			[self.sceneCapture.navigationController popViewControllerAnimated:YES];
	}];
}

@end