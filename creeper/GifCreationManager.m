//
//  GifCreationManager.m
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

#import "GifCreationManager.h"
#import <giflib/GifEncode.h>
#import <giflib/giflib_ios.h>
#import "FeedItem.h"
#import "CreeperDataExtensions.h"

@interface GifCreationManager ()

@property (nonatomic, strong) NSMutableDictionary *encoders;

@end

@implementation GifCreationManager

- (id)init
{
    self = [super init];
    if (self)
	{
		self.encoders = [NSMutableDictionary dictionary];
    }
    return self;
}

static GifCreationManager *_sharedInstance = nil;

+(GifCreationManager *)sharedInstance
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[GifCreationManager alloc] init];
	});
	
	return _sharedInstance;
}

+(GifCreationQueue *)queueByID:(NSString *)encoderID
{
	return [[[self sharedInstance] encoders] objectForKey:encoderID];
}

#pragma mark - Background processing

+(NSString *)storageLocationForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex
{
	if (!encoderID)
	{
		return nil;
	}
	
	NSArray  *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir  = [documentPaths objectAtIndex:0];	
	NSString *outputDir    = [documentsDir stringByAppendingPathComponent:@"GCM"];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	if (![mgr fileExistsAtPath:outputDir])
	{
		[mgr createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	
	return [outputDir stringByAppendingPathComponent:
					  [NSString stringWithFormat:@"%@_%d.gif", encoderID, imageIndex]];
}

-(NSString *)createEncoderWithSize:(CGSize)size
{
	GifCreationQueue *newQueue = [[GifCreationQueue alloc] init];
	
	CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
	NSString *uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
	CFRelease(newUniqueId);
	newQueue.encoderID = uuidString;

	newQueue.size = size;
	NSString *outFile = [GifCreationManager storageLocationForEncoderID:newQueue.encoderID imageIndex:newQueue.imageIndex];

	newQueue.encoder = [[GifEncode alloc] initWithFile:outFile
									   targetSize:size
											 loopCount:0
											  optimize:YES];
	
	[self.encoders setObject:newQueue forKey:newQueue.encoderID];
	return newQueue.encoderID;
}

-(void)closeEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	encoderQueue.closed = YES;
	
	@synchronized(_sharedInstance)
	{
		FeedItem *queueItem = [FeedItem withEncoderID:encoderID];
		
		if ([queueItem.frameCount isEqualToNumber:queueItem.frameEncodingCount])
		{
			queueItem.feedItemType = FeedItemType_Encoded;
			[FeedItem save];
		}		
	}
}

-(void)clearEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	
	if (encoderQueue.encoder)
	{
		[encoderQueue.encoder close];
	}
	[self.encoders removeObjectForKey:encoderID];
}


-(void)addFrame:(GifQueueFrame *)gifFrame toEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	[encoderQueue addGifFrame:gifFrame];
}

@end

#pragma mark -

@interface GifCreationQueue ()

@property (nonatomic, assign) NSUInteger lastSize;

@end

@implementation GifCreationQueue

@dynamic storageSize;
-(NSUInteger)storageSize
{
	if (self.lastSize==0)
	{
		NSFileManager *mgr = [NSFileManager defaultManager];
		NSDictionary *fileAttributes = [mgr attributesOfItemAtPath:[GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:self.imageIndex] error:nil];
		self.lastSize = (NSUInteger)fileAttributes.fileSize;
	}
	
	return self.lastSize;
}

@dynamic approxStorageFrameSize;
-(NSUInteger)approxStorageFrameSize
{
	if (self.encodedFrameCount<5)
	{
		// The estimate is wonky until we get a few frames processed.
		return 25000;
	}
	return (NSUInteger)floor(self.storageSize/self.encodedFrameCount);
}

-(void)incrementFrameCount
{
	FeedItem *queueItem = [FeedItem withEncoderID:self.encoderID];
	if (queueItem)
	{
		queueItem.frameCount = [NSNumber numberWithInt:[queueItem.frameCount integerValue] + 1];
		[FeedItem save];
		self.frameCount = [queueItem.frameCount integerValue];
	}
}

-(void)addGifFrame:(GifQueueFrame *)frm
{
	@synchronized(self)
	{
		if (self.closed)
		{
			DLog(@"Add frame after close? come on.");
		}
		else
		{
			frm.encoderID = self.encoderID;
			__weak GifCreationQueue *blockSelf = self;
			__block GifQueueFrame *blockLast = self.lastOperation;
			__block GifQueueFrame *blockOperation = frm;
			[frm setCompletionBlock:^{
				if ([blockLast isEqual:blockOperation])
				{
					[blockSelf setLastOperation:nil];
				}
			}];
			if (self.lastOperation)
			{
				[frm addDependency:self.lastOperation];
			}
			self.lastOperation = frm;
			[self addOperation:frm];
			frm.frameIndex = self.frameCount+1;
			[self performSelectorOnMainThread:@selector(incrementFrameCount) withObject:nil waitUntilDone:NO];
		}
	}
}

@end

#pragma mark -

@implementation GifQueueFrame

@synthesize frameAddedFinished;
-(void)setFrameAddedFinished:(BOOL)value
{
	if (frameAddedFinished!=value)
	{
		[self willChangeValueForKey:@"isFinished"];
		frameAddedFinished = value;
		[self didChangeValueForKey:@"isFinished"];
	}
}

@synthesize frameProcessing;
-(void)setFrameProcessing:(BOOL)value
{
	if (frameProcessing!=value)
	{
		[self willChangeValueForKey:@"isExecuting"];
		frameProcessing = value;
		[self didChangeValueForKey:@"isExecuting"];
	}
}

+(id)withImage:(UIImage *)img andDelay:(NSTimeInterval)frmDelay
{
	GifQueueFrame *frm = [[self alloc] init];
	frm.img = img;
	frm.frmDelay = frmDelay;
	return frm;
}

-(BOOL)isConcurrent
{
	return YES;
}

-(BOOL)isFinished
{
	return self.frameAddedFinished;
}

-(BOOL)isExecuting
{
	return self.frameProcessing;
}

-(void)incrementEncodedCount
{
	// Lets do this on the main thread.
	if (![NSThread isMainThread])
	{
		[self performSelectorOnMainThread:@selector(incrementEncodedCount) withObject:nil waitUntilDone:NO];
		return;
	}
	
	@synchronized(_sharedInstance)
	{
		FeedItem *queueItem = [FeedItem withEncoderID:self.encoderID];
		queueItem.frameEncodingCount = [NSNumber numberWithInt:[queueItem.frameEncodingCount integerValue] + 1];
		GifCreationQueue *queue = [GifCreationManager queueByID:self.encoderID];
		queue.encodedFrameCount = [queueItem.frameEncodingCount intValue];
		queue.lastSize = 0;
		
		if ([queueItem.frameCount isEqualToNumber:queueItem.frameEncodingCount])
		{
			if (queue.closed)
			{
				queueItem.feedItemType = FeedItemType_Encoded;
			}
		}
		
		[FeedItem save];
	}
}

-(void)main
{
	if ([self isCancelled]) {
		return;
	}
	
	GifCreationQueue *queue = [GifCreationManager queueByID:self.encoderID];
	
	if (queue)
	{
		CGRect imgBounds = CGRectMake(0, 0, self.img.size.width, self.img.size.height);
		[queue.encoder putImageAsFrame:self.img
					 frameBounds:imgBounds
					   delayTime:self.frmDelay
					disposalMode:DISPOSE_DO_NOT
				  alphaThreshold:0.5];
	}
	
	queue.lastEncodedFrame = self.img;
	[self incrementEncodedCount];
	
	self.frameAddedFinished = YES;
	self.frameProcessing = NO;
}

- (void)start
{
	// Always check for cancellation before launching the task.
	if ([self isCancelled])
	{
		self.frameAddedFinished = YES;
		return;
	}
	
	// If the operation is not canceled, begin executing the task.
	[self willChangeValueForKey:@"isExecuting"];
	[NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
	frameProcessing = YES; // Do not use property, set ivar directly.
	[self didChangeValueForKey:@"isExecuting"];
}

@end