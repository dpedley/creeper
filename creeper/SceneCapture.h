//
//  CreepCam.h
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SceneCapture : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, assign) int frameCount;
@property (nonatomic, readonly) int encodingWorkload;
@property (nonatomic, readonly) NSData *imageData;

-(void)completeEncoding;

@end
