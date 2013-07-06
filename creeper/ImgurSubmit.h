//
//  ImgurSubmit.h
//  creeper
//
//  Created by Douglas Pedley on 4/10/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FeedItem;

@interface ImgurSubmit : UIViewController

@property (nonatomic, strong) FeedItem *item;

+(NSString *)uniqueName;

@end
