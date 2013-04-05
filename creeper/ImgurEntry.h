//
//  ImgurEntry.h
//  creeper
//
//  Created by Douglas Pedley on 4/4/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class FeedItem;

@interface ImgurEntry : NSManagedObject

@property (nonatomic, retain) NSString * deletehash;
@property (nonatomic, retain) NSString * imgDescription;
@property (nonatomic, retain) NSString * imgName;
@property (nonatomic, retain) NSString * imgTitle;
@property (nonatomic, retain) NSString * imgurID;
@property (nonatomic, retain) NSString * link;
@property (nonatomic, retain) NSNumber * timestamp;
@property (nonatomic, retain) FeedItem *feedItem;

@end
