//
//  ImgurIOS.h
//  creeper
//
//  Created by Douglas Pedley on 3/1/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImgurEntry.h"

@interface ImgurEntry (LocalImageCacheAdditions)

@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) NSData *imageData;

@end


@interface ImgurIOS : NSObject

+(void)uploadImageData:(NSData *)data name:(NSString *)theName title:(NSString *)theTitle description:(NSString *)theDescription uploadComplete:(void (^)(BOOL success))completion;
+(void)deleteImageWithHashToken:(NSString *)hashToken deleteComplete:(void (^)(BOOL success))completion;

@end
