//
//  GifCreationManager.h
//  creeper
//
//  Created by Douglas Pedley on 3/28/13.
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

#import <Foundation/Foundation.h>

#define GifMan(theID) [[GifCreationManager sharedInstance] encoderByID:theID]

@class GifCreationManager;
@class GifCreationQueue;
@class GifQueueFrame;

@interface GifCreationManager : NSObject

+(void)removeEncodedImagesForEncoderID:(NSString *)encoderID;
+(NSString *)storageLocationForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex;
+(UIImage *)previewFrameForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex;

+(GifCreationQueue *)queueByID:(NSString *)encoderID;
+(GifCreationManager *)sharedInstance;
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
@property (nonatomic, assign) int encodedFrameCount;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) BOOL closed;
@property (nonatomic, strong) GifQueueFrame *lastOperation;
@property (nonatomic, readonly) NSUInteger storageSize;
@property (nonatomic, readonly) NSUInteger approxStorageFrameSize;

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