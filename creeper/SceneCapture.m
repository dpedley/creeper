//
//  CreepCam.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import "SceneCapture.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/CALayer.h>
#import <giflib/GifEncode.h>
#import <giflib/giflib_ios.h>
#import "ImageInfo.h"

static int SceneCapture_ClearAlert = 404;
static int SceneCapture_ResolutionChangeAlert = 204;
static int SceneCapture_RotationAlert = 104;

static int maxFrameCount_Small = 50;
static int maxFrameCount_Large = 16;

@interface SceneCapture ()

@property (nonatomic, strong) IBOutlet UIView *screenShotView;
@property (nonatomic, strong) IBOutlet UIProgressView *animationProgress;
@property (nonatomic, strong) IBOutlet UILongPressGestureRecognizer *longPress;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *frameDisplay;
@property (nonatomic, strong) IBOutlet UISegmentedControl *resolutionSelect;
@property (nonatomic, assign) BOOL animationActive;
@property (nonatomic, strong) NSMutableArray *animationFrames;
@property (nonatomic, assign) int previewFrameCount;
@property (nonatomic, strong) GifEncode *encoder;
@property (nonatomic, assign) BOOL encoderActive;
@property (nonatomic, readonly) int maxFrameCount;

-(IBAction)recordActionStateChange:(id)sender;
-(IBAction)clearRecordingAction:(id)sender;
-(IBAction)changeResolution:(id)sender;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

-(void)createAnimatedGifFromFrames;
-(NSString *)temporaryFileLocation;

@end

@implementation SceneCapture

@dynamic encodingWorkload;
-(int)encodingWorkload
{
	if (self.encoderActive)
	{
		return [self.animationFrames count] + 1;
	}
	
	return [self.animationFrames count];
}

@dynamic imageData;
-(NSData *)imageData
{
	return [NSData dataWithContentsOfFile:[self temporaryFileLocation]];
}

@dynamic maxFrameCount;
-(int)maxFrameCount
{
	if (self.resolutionSelect.selectedSegmentIndex==1)
	{
		return maxFrameCount_Large;
	}
	return maxFrameCount_Small;
}

#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"ShowInfoSegue"])
	{
        ImageInfo *ii = [segue destinationViewController];
		ii.cc = self;
    }
}

#pragma mark - utilities

-(void)completeEncoding
{
	[self.encoder close];
}

-(NSString *)temporaryFileLocation
{
	return [NSHomeDirectory() stringByAppendingString:@"/Library/Caches/temp.gif"];
}

-(void)updateFrameDisplay
{
	[self.frameDisplay performSelectorOnMainThread:@selector(setTitle:) withObject:[NSString stringWithFormat:@"%d/%d", self.frameCount, self.maxFrameCount] waitUntilDone:NO];
}

- (void)setupCaptureSession
{
    NSError *error = nil;
	
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
	
	[self updateFrameDisplay];
	
    // Create the session
    self.session = [[AVCaptureSession alloc] init];

	if (self.resolutionSelect.selectedSegmentIndex==1)
	{
		self.session.sessionPreset = AVCaptureSessionPresetMedium;
	}
	else
	{
		self.session.sessionPreset = AVCaptureSessionPresetLow;
	}
	
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
			NSLog(@"Couldn't add input");
			[SVProgressHUD dismiss];
			return;
		}
		
		// Add Audio Input
//		NSLog(@"Adding audio input");
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
			conn.videoMinFrameDuration = CMTimeMake(1, 12);
		if (conn.isVideoMaxFrameDurationSupported)
			conn.videoMaxFrameDuration = CMTimeMake(1, 12);
		
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
		CGRect frm = self.screenShotView.bounds;
		self.screenShotView.frame = frm;
		NSLog(@"frm: %f %f %f %f", frm.origin.x, frm.origin.y, frm.size.width, frm.size.height);
		self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
		[self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
		self.previewLayer.frame = CGRectMake(0, 0, frm.size.width, frm.size.height);
		
		AVCaptureConnection *previewLayerConnection=self.previewLayer.connection;
		if ([previewLayerConnection isVideoOrientationSupported])
		{
			[previewLayerConnection setVideoOrientation:conn.videoOrientation];
		}
		[self.screenShotView.layer addSublayer:self.previewLayer];
	}
	[SVProgressHUD dismiss];
}

#pragma mark - Actions

-(IBAction)recordActionStateChange:(id)sender
{
	switch (self.longPress.state)
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
			self.encoder = nil;
			[self.animationFrames removeAllObjects];
			[self.animationProgress setProgress:0.0 animated:YES];
			self.frameCount = 0;
			[self updateFrameDisplay];
		}
		else
		{
			// Cancelled
		}
	}
	else if (alertView.tag==SceneCapture_ResolutionChangeAlert)
	{
		if (buttonIndex==1)
		{
			self.encoder = nil;
			[self.animationFrames removeAllObjects];
			[self.animationProgress setProgress:0.0 animated:YES];
			self.frameCount = 0;
			[SVProgressHUD showWithStatus:@"Changing resolution" maskType:SVProgressHUDMaskTypeGradient];
			[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
		}
		else
		{
			// Cancelled
			[self.resolutionSelect setSelectedSegmentIndex:(self.resolutionSelect==0)?1:0];
		}
	}
	else if (alertView.tag==SceneCapture_RotationAlert)
	{
		if (buttonIndex==1)
		{
			self.encoder = nil;
			[self.animationFrames removeAllObjects];
			[self.animationProgress setProgress:0.0 animated:YES];
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

-(IBAction)changeResolution:(id)sender
{
	if (self.encoder || self.frameCount>0)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Change resolution" message:@"To change resolution will clear your current recording?" delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		alert.tag = SceneCapture_ResolutionChangeAlert;
		[alert show];
	}
	else
	{
		[SVProgressHUD showWithStatus:@"Changing resolution" maskType:SVProgressHUDMaskTypeGradient];
		[self performSelectorInBackground:@selector(setupCaptureSession) withObject:nil];
	}
}


#pragma mark - Object lifecycle

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
	self.animationFrames = [NSMutableArray array];
}

-(void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
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

#pragma mark - Utilities

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

-(void)createAnimatedGifFromFrames
{
	if ( (self.encoderActive) || ([self.animationFrames count]==0) )
	{
		return;
	}
	self.encoderActive = YES;
	
	NSTimeInterval frmDelay = 0.333;
	CGRect imgBounds;
	
	while ( [self.animationFrames count] > 0 )
	{
		UIImage *img = [self.animationFrames objectAtIndex:0];
		[self.animationFrames removeObjectAtIndex:0];
		NSLog( @"Encode frame... %d", [self.animationFrames count]);
		
		if (!self.encoder)
		{
			self.encoder = [[GifEncode alloc] initWithFile:[self temporaryFileLocation]
										   targetSize:img.size
											loopCount:0
											 optimize:YES ];
			if (self.encoder.error != 0)
			{
				NSLog(@"Encoder init error: %d", self.encoder.error);
				return;
			}
			
		}
		imgBounds = CGRectMake(0, 0, img.size.width, img.size.height);
		
		[self.encoder putImageAsFrame:img
					 frameBounds:imgBounds
					   delayTime:frmDelay
					disposalMode:DISPOSE_DO_NOT
				  alphaThreshold:0.5];
		
		if (self.encoder.error != 0)
		{
			NSLog(@"Encoder put image error: %d", self.encoder.error);
			return;
		}
	}
		
	self.encoderActive = NO;
	NSLog(@"Ok now try to upload");
}

-(void)updateProgress
{
	[self.animationProgress setProgress: ( (double)self.frameCount / (double)self.maxFrameCount ) animated:NO];
}

#pragma mark - The delegate

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
	self.previewFrameCount++;
	if ((self.previewFrameCount%4)==1)
	{
		if ( (self.animationActive) && (self.frameCount < self.maxFrameCount) )
		{
			self.frameCount++;
			[self updateFrameDisplay];
			NSLog(@"Capturing image [%d]: %@", self.frameCount, [NSDate date]);
			// Create a UIImage from the sample buffer data
			UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
			
			[self.animationFrames addObject:image];
			[self performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
			[self performSelectorInBackground:@selector(createAnimatedGifFromFrames) withObject:nil];
		}
	}

}


@end
