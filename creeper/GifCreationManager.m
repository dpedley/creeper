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
#import <giflib-ios/GifEncode.h>
#import <giflib-ios/GifDecode.h>
#import <giflib-ios/giflib_ios.h>
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import <stdint.h>

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

+(NSString *)GCMdir
{
	NSArray  *documentPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDir  = [documentPaths objectAtIndex:0];
	NSString *outputDir    = [documentsDir stringByAppendingPathComponent:@"GCM"];
	
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	if (![mgr fileExistsAtPath:outputDir])
	{
		[mgr createDirectoryAtPath:outputDir withIntermediateDirectories:YES attributes:nil error:nil];
	}
	return outputDir;
}

+(void)removeEncodedImagesForEncoderID:(NSString *)encoderID
{
	NSFileManager *mgr = [NSFileManager defaultManager];
	int i=0;
	
	NSString *theGIF     = [self storageLocationForEncoderID:encoderID imageIndex:i];
	NSString *thePreview = [self storageLocationForEncoderID:encoderID previewImageIndex:i];
	
	while ([mgr fileExistsAtPath:theGIF])
	{
		[mgr removeItemAtPath:theGIF error:nil];
		[mgr removeItemAtPath:thePreview error:nil];
		
		i++;
		theGIF     = [self storageLocationForEncoderID:encoderID imageIndex:i];
		thePreview = [self storageLocationForEncoderID:encoderID previewImageIndex:i];
	}
}


+(NSString *)storageLocationForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex
{
	if (!encoderID)
	{
		return nil;
	}
	
	NSString *outputDir = [self GCMdir];
	return [outputDir stringByAppendingPathComponent:
					  [NSString stringWithFormat:@"%@_%d.gif", encoderID, imageIndex]];
}

+(NSString *)storageLocationForEncoderID:(NSString *)encoderID previewImageIndex:(int)imageIndex
{
	if (!encoderID)
	{
		return nil;
	}
	
	NSString *outputDir = [self GCMdir];
	return [outputDir stringByAppendingPathComponent:
			[NSString stringWithFormat:@"%@_%d_preview.png", encoderID, imageIndex]];
}

+(UIImage *)previewFrameForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex
{
	if (!encoderID)
	{
		return nil;
	}
	
	NSString *theGIF = [self storageLocationForEncoderID:encoderID previewImageIndex:imageIndex];
		
	NSFileManager *mgr = [NSFileManager defaultManager];
	
	UIImage *frm = nil;
	
	if (![mgr fileExistsAtPath:theGIF])
	{
		NSMutableArray *frames = [NSMutableArray array];
		[GifDecode decodeGifFramesFromFile:[self storageLocationForEncoderID:encoderID imageIndex:imageIndex] storeFramesIn:frames storeInfo:nil separateFrameOnly:NO];
		if (frames && [frames count]>0)
		{
			frm = [frames objectAtIndex:floor([frames count]/2)];
			NSData *pngData = UIImagePNGRepresentation(frm);
			if (pngData)
			{
				[pngData writeToFile:theGIF atomically:NO];
			}
		}
	}
	else
	{
		frm = [[UIImage alloc] initWithContentsOfFile:theGIF];
	}
	
	return frm;
}

+(NSData *)dataPaddingForEncoderID:(NSString *)encoderID imageIndex:(int)imageIndex
{
	NSData *gifData = [NSData dataWithContentsOfFile:[GifCreationManager storageLocationForEncoderID:encoderID imageIndex:imageIndex]];
	return [gifData dataPaddingGIF];
}

-(NSString *)createEncoderWithSize:(CGSize)size
{
	GifCreationQueue *newQueue = [[GifCreationQueue alloc] init];
	
	newQueue.audioData = [NSMutableData data];
	
	CFUUIDRef newUniqueId = CFUUIDCreate(kCFAllocatorDefault);
	NSString *uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(kCFAllocatorDefault, newUniqueId);
	CFRelease(newUniqueId);
	newQueue.encoderID = uuidString;

	newQueue.size = size;
	NSString *outFile = [GifCreationManager storageLocationForEncoderID:newQueue.encoderID imageIndex:newQueue.imageIndex];

	newQueue.encoder = [[GifEncode alloc] initWithFile:outFile
									   targetSize:size
											 loopCount:0
											  optimize:NO];
	
	[self.encoders setObject:newQueue forKey:newQueue.encoderID];
	return newQueue.encoderID;
}

-(void)closeEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	encoderQueue.closed = YES;
	
	@synchronized(_sharedInstance)
	{
		FeedItem *queueItem = [FeedItem withEncoderID:encoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
		if ([queueItem.frameCount isEqualToNumber:queueItem.frameEncodingCount])
		{
			[encoderQueue.encoder close];
			[self.encoders removeObjectForKey:encoderID];
			[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
				FeedItem *localItem = [FeedItem withEncoderID:encoderID inContext:localContext];
				localItem.feedItemType = FeedItemType_Encoded;
			} completion:^(BOOL success, NSError *error) {
				[encoderQueue storageAppendAudioData];
			}];
		}
	}
}

-(void)clearEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	
	if (encoderQueue)
	{
		[encoderQueue cancelAllOperations];
		[encoderQueue waitUntilAllOperationsAreFinished];
		if (encoderQueue.encoder)
		{
			[encoderQueue.encoder close];
		}
		[self.encoders removeObjectForKey:encoderID];
	}
}


-(void)addFrame:(GifQueueFrame *)gifFrame toEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	[encoderQueue addGifFrame:gifFrame];
}

-(void)addAudioData:(NSData *)data toEncoder:(NSString *)encoderID
{
	GifCreationQueue *encoderQueue = [self.encoders objectForKey:encoderID];
	[encoderQueue addAudioData:data];
}

@end

#pragma mark -

@interface GifCreationQueue ()

@property (nonatomic, assign) BOOL lockedWhileAddingFrame;
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
	if (self.encodedFrameCount<2)
	{
		// The estimate is wonky until we get a few frames processed.
		return 55000;
	}
	return (NSUInteger)floor(self.storageSize/self.encodedFrameCount);
}

-(void)incrementFrameCount
{
	self.frameCount++;
	
	if (!self.lockedWhileAddingFrame)
	{
		self.lockedWhileAddingFrame = YES;
		FeedItem *queueItem = [FeedItem withEncoderID:self.encoderID inContext:[NSManagedObjectContext contextForCurrentThread]];
		if (queueItem)
		{
			__weak GifCreationQueue *blockSelf = self;
			[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
				FeedItem *localItem = [FeedItem withEncoderID:blockSelf.encoderID inContext:localContext];
				localItem.frameCount = [NSNumber numberWithInt:blockSelf.frameCount];
			} completion:^(BOOL success, NSError *error) {
				blockSelf.lockedWhileAddingFrame = NO;
			}];
		}
		else
		{
			self.lockedWhileAddingFrame = NO;
		}
	}
}

-(void)addGifFrame:(GifQueueFrame *)frm
{
	if (self.closed)
	{
		DLog(@"Add frame after close? come on.");
	}
	else
	{
		frm.frameIndex = self.frameCount + 1;
		[self incrementFrameCount];
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
	}
}

-(void)addAudioData:(NSData *)data
{
	[self.audioData appendData:data];
}

-(void)storageAppendAudioData
{
	if (!self.closed)
	{
		DLog(@"Cannot call storageAppendAudioData before closing queue.");
		return;
	}
	
	if (!self.audioData)
	{
		return;
	}
	
	NSString *theGIF = [GifCreationManager storageLocationForEncoderID:self.encoderID imageIndex:self.imageIndex];
	NSFileManager *mgr = [NSFileManager defaultManager];

	if ([mgr fileExistsAtPath:theGIF])
	{
		NSMutableData *fileData = [[NSData dataWithContentsOfFile:theGIF options:0 error:nil] mutableCopy];
		[fileData appendData:self.audioData];
		[mgr removeItemAtPath:theGIF error:nil];
		[fileData writeToFile:theGIF atomically:NO];
		
//		// A little debugging
//		[self.audioData writeToFile:[theGIF stringByAppendingString:@"rawaudio"] atomically:NO];		
		self.audioData = nil;
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
	@synchronized(_sharedInstance)
	{
		__weak GifQueueFrame *blockSelf = self;
		[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
			GifCreationQueue *queue = [GifCreationManager queueByID:blockSelf.encoderID];
			queue.encodedFrameCount++;
			queue.lastSize = 0;
			
			FeedItem *queueItem = [FeedItem withEncoderID:blockSelf.encoderID inContext:localContext];
			queueItem.frameEncodingCount = [NSNumber numberWithInt:[queueItem.frameEncodingCount integerValue] + 1];
			
//			DLog(@"Storage size: [ %d / %d = %f ]", queue.storageSize, queue.encodedFrameCount, (float)queue.storageSize / (float)queue.encodedFrameCount);
			
			if (queue.frameCount==queue.encodedFrameCount)
			{
				if (queue.closed)
				{
					[queue.encoder close];
					[[GifCreationManager sharedInstance].encoders removeObjectForKey:blockSelf.encoderID];
					queueItem.feedItemType = FeedItemType_Encoded;
					[queue storageAppendAudioData];
				}
			}
		} completion:^(BOOL success, NSError *error) {
		}];
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
//		DLog(@"[main] frameCount: %d frameEncodedCount: %d", queue.frameCount, queue.encodedFrameCount);
//		NSTimeInterval beforeTimer = [NSDate timeIntervalSinceReferenceDate];
		CGRect imgBounds = CGRectMake(0, 0, self.img.size.width, self.img.size.height);
		[queue.encoder putImageAsFrame:self.img
					 frameBounds:imgBounds
					   delayTime:self.frmDelay
					disposalMode:DISPOSE_DO_NOT
				  alphaThreshold:0.5];
//		DLog(@"Encoding timing: %f", [NSDate timeIntervalSinceReferenceDate] - beforeTimer);
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

@implementation NSData (GifDataPadding)

-(NSData *)dataLeftAfterRange:(NSRange)range
{
	return [self subdataWithRange:NSMakeRange(range.location + range.length, self.length - (range.location + range.length - 1))];
}

enum gifByteDefines
{
	gifGraphicControlLabel  = 0xf9,
	gifImageSeparator       = 0x2c,
	gifExtensionIntroducer  = 0x21,
	gifExtensionTerminator  = 0x00,
	gifApplicationExtension = 0xff,
	gifTrailer              = 0x3b
};


-(UInt16)gifBytes:(Byte *)gifBytes extensionLengthAtIndex:(UInt32)idx
{
	if (gifBytes[idx]==gifExtensionIntroducer)
	{
		if (gifBytes[idx+1]==gifGraphicControlLabel)
		{
			Byte blockSize = gifBytes[idx+2];
			if (gifBytes[idx + blockSize + 3]==gifExtensionTerminator)
			{
				return blockSize + 4;
			}
		}
		else if (gifBytes[idx+1]==gifApplicationExtension)
		{
			Byte blockSize = gifBytes[idx+2];
			UInt16 newOffset = blockSize + 3;
			while (gifBytes[idx + newOffset]!=gifExtensionTerminator)
			{
				newOffset += ( gifBytes[idx + newOffset] + 1 );
			}
			newOffset++; // the gifExtensionTerminator
			return newOffset;
		}
		else
		{
			DLog(@"Unknown extension %x ", gifBytes[idx+1]);
		}
	}
	
	return 0;
}

-(UInt16)gifBytes:(Byte *)gifBytes imageDescriptorLengthAtIndex:(UInt32)idx
{
	if (gifBytes[idx]==gifImageSeparator)
	{
		/* // Unused for now
		UInt16 *gifLeft = (UInt16 *)&(gifBytes[idx+1]);
		UInt16 *gifTop = (UInt16 *)&(gifBytes[idx+3]);
		UInt16 *gifWidth = (UInt16 *)&(gifBytes[idx+5]);
		UInt16 *gifHeight = (UInt16 *)&(gifBytes[idx+7]);
		*/
		
		Byte *packedBits = &(gifBytes[idx+9]);
		
		BOOL lctFlag = ( ((*packedBits) & 128 ) > 0);
		Byte lctSize = (*packedBits) & 7;
		
		DLog(@"lctSize: %d", lctSize);

		UInt16 descriptorSize = 10;
		
		DLog(@"descriptorSize: %d", descriptorSize);
		if (lctFlag)
		{
			UInt16 colorTableSize = (UInt16)pow( 2, (double)(lctSize + 1));
			descriptorSize += ( colorTableSize * 3 );
		}
		DLog(@"descriptorSize: %d", descriptorSize);
		
		return descriptorSize;
	}
	
	return 0;
}

-(NSData *)dataPaddingGIF
{
		
	NSData *parse = nil;
	Byte *gifBytes = (Byte *)self.bytes;
	if ( (gifBytes[0]='G') && (gifBytes[1]='I') && (gifBytes[2]='F') && (gifBytes[3]='8') && (gifBytes[4]='9') && (gifBytes[5]='a') )
	{
		// header is fine
		UInt16 *gifWidth = (UInt16 *)&(gifBytes[6]);
		UInt16 *gifHeight = (UInt16 *)&(gifBytes[8]);
		Byte *packedBits = &(gifBytes[10]);
		
		BOOL gctFlag = ( ((*packedBits) & 128 ) > 0);
		/* // Unused for now
		Byte colorDepth = ( ( (*packedBits) & 112 ) << 4) + 1;
		BOOL sortFlag = ( ((*packedBits) & 8 ) > 0);
		 */
		
		Byte gctSize = (*packedBits) & 7;
		
		/* // Unused for now
		Byte *bgColor = &(gifBytes[11]);
		Byte *pixelAspectRatio = &(gifBytes[12]);
		 */
		
		UInt16 colorTableSize = (UInt16)pow( 2, (double)(gctSize + 1));
		UInt16 gctTableSize = ( colorTableSize * 3 );
		
		DLog(@"The image is: %d x %d", *gifWidth, *gifHeight);
		DLog(@"color table %d %d %d %d %d", gifBytes[10], gctFlag, gctSize, colorTableSize, gctTableSize);
		
		
		// At the end roamingByteIndex -> EOF should be the padding.
		UInt32 roamingByteIndex = (gctFlag)?gctTableSize+13:13;
		BOOL gifComplete = NO;

		DLog(@"block: %@", [self subdataWithRange:NSMakeRange(0, 32)]);

		DLog(@"initial block: [%d] %@", (int)roamingByteIndex, [self subdataWithRange:NSMakeRange(0, roamingByteIndex)]);
		
		while (!gifComplete)
		{
			int currentByteOffset = roamingByteIndex;
			
			switch (gifBytes[roamingByteIndex])
			{
				case gifExtensionIntroducer:
					roamingByteIndex += [self gifBytes:gifBytes extensionLengthAtIndex:roamingByteIndex];
					break;
					
				case gifImageSeparator:
					roamingByteIndex += [self gifBytes:gifBytes imageDescriptorLengthAtIndex:roamingByteIndex];
					break;
					
				case gifTrailer:
				{
					roamingByteIndex++;
					if (roamingByteIndex<self.length)
					{
						return [self subdataWithRange:NSMakeRange(roamingByteIndex, self.length-roamingByteIndex)];
					}
					return nil;
				}
				default:
				{
					// Here we're assuming this is lzw compress image data blocks
					
					roamingByteIndex++; // skip the lzw minimum code size
					while (gifBytes[roamingByteIndex]!=gifExtensionTerminator)
					{
						roamingByteIndex += ( gifBytes[roamingByteIndex] + 1 );
					}
					roamingByteIndex++; // skip the gifExtensionTerminator
					
				}
					break;
			}
			
			if (currentByteOffset!=roamingByteIndex)
			{
				int len = roamingByteIndex-currentByteOffset;
				if (len>100)
				{
					DLog(@"processed block: [%d]\n%@\n%@", len, [self subdataWithRange:NSMakeRange(currentByteOffset, 40)], [self subdataWithRange:NSMakeRange(roamingByteIndex-40, 40)]);
				}
				else
				{
					DLog(@"processed block: [%d] %@", len, [self subdataWithRange:NSMakeRange(currentByteOffset, len)]);
				}
			}
			else
			{
				gifComplete = YES;
				DLog(@"failed block: %@", [self subdataWithRange:NSMakeRange(currentByteOffset, 10)]);
			}
		}
	}
	
	return parse;
}

@end