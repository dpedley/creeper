//
//  FeedItem.h
//  creeper
//
//  Created by Douglas Pedley on 4/4/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class ImgurEntry, RedditPost;

@interface FeedItem : NSManagedObject

@property (nonatomic, retain) NSString * encoderID;
@property (nonatomic, retain) NSNumber * frameCount;
@property (nonatomic, retain) NSNumber * frameEncodingCount;
@property (nonatomic, retain) NSNumber * itemType;
@property (nonatomic, retain) NSString * statusString;
@property (nonatomic, retain) NSDate * timestamp;
@property (nonatomic, retain) ImgurEntry *imgur;
@property (nonatomic, retain) RedditPost *reddit;

@end
