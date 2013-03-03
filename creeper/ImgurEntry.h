//
//  ImgurEntry.h
//  creeper
//
//  Created by Douglas Pedley on 3/2/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface ImgurEntry : NSManagedObject

@property (nonatomic, retain) NSString * deletehash;
@property (nonatomic, retain) NSString * imgurID;
@property (nonatomic, retain) NSString * link;
@property (nonatomic, retain) NSString * imgName;
@property (nonatomic, retain) NSString * imgTitle;
@property (nonatomic, retain) NSString * imgDescription;
@property (nonatomic, retain) NSNumber * timestamp;

@end
