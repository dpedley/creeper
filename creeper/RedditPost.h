//
//  RedditPost.h
//  creeper
//
//  Created by Douglas Pedley on 4/4/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class FeedItem;

@interface RedditPost : NSManagedObject

@property (nonatomic, retain) NSString * redditID;
@property (nonatomic, retain) NSString * postName;
@property (nonatomic, retain) NSString * redditURL;
@property (nonatomic, retain) FeedItem *feedItem;

@end
