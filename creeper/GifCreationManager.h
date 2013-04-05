//
//  GifCreationManager.h
//  creeper
//
//  Created by Douglas Pedley on 3/28/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>

#define GifMan(theID) [[GifCreationManager sharedInstance] encoderByID:theID]

@class GifCreationManager;
@class GifCreationQueue;
@class GifQueueFrame;

@interface GifCreationManager : NSObject

+(NSString *)storageLocationForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex;
+(GifCreationManager *)sharedInstance;
+(GifCreationQueue *)queueByID:(NSString *)encoderID;
-(NSString *)createEncoderWithSize:(CGSize)size;
-(void)addFrame:(GifQueueFrame *)gifFrame toEncoder:(NSString *)encoderID;
-(void)closeEncoder:(NSString *)encoderID;
-(void)clearEncoder:(NSString *)encoderID;

@end

@class GifEncode;

@interface GifCreationQueue : NSOperationQueue

@property (nonatomic, strong) UIImage *lastEncodedFrame;
@property (nonatomic, strong) NSString *encoderID;
@property (nonatomic, strong) GifEncode *encoder;
@property (nonatomic, assign) int imageIndex; // Spanning multi animation gifs
@property (nonatomic, assign) int frameCount; 
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) GifQueueFrame *lastOperation;

-(void)addGifFrame:(GifQueueFrame *)frm;

@end

@interface GifQueueFrame : NSOperation;

@property (nonatomic, assign) int frameIndex;
@property (nonatomic, assign) BOOL frameAddedFinished;
@property (nonatomic, assign) BOOL frameProcessing;
@property (nonatomic, strong) UIImage *img;
@property (nonatomic, assign) NSTimeInterval frmDelay;
@property (nonatomic, strong) NSString *encoderID;

+(id)withImage:(UIImage *)img andDelay:(NSTimeInterval)frmDelay;

@end