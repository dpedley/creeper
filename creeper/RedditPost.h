//
//  RedditPost.h
//  creeper
//
//  Created by Douglas Pedley on 5/29/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class FeedItem;

@interface RedditPost : NSManagedObject

@property (nonatomic, retain) NSString * author;
@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSString * domain;
@property (nonatomic, retain) NSNumber * hotOrder;
@property (nonatomic, retain) NSString * imgurLink;
@property (nonatomic, retain) NSNumber * over18Number;
@property (nonatomic, retain) NSString * redditID;
@property (nonatomic, retain) NSString * redditName;
@property (nonatomic, retain) NSString * redditTitle;
@property (nonatomic, retain) NSString * redditURL;
@property (nonatomic, retain) NSNumber * score;
@property (nonatomic, retain) NSString * validationString;
@property (nonatomic, retain) FeedItem *feedItem;

@end
