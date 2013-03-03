//
//  ImgurCell.h
//  creeper
//
//  Created by Douglas Pedley on 3/2/13.
//  Copyright (c) 2013 dpedley. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImgurEntry;

@interface ImgurCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView *preview;
@property (nonatomic, strong) IBOutlet UILabel *infoLabel;
@property (nonatomic, strong) IBOutlet UILabel *timestampLabel;

-(void)configureWithEntry:(ImgurEntry *)entry;

@end
