//
//  AnimationListController.m
//  creeper
//
//  Created by Douglas Pedley on 2/27/13.
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

#import "AnimationListController.h"
#import "ImgurWebViewController.h"
#import "GifProcessingCell.h"
#import "ImgurEntry.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "ImgurIOS.h"
#import "iOSRedditAPI.h"
#import "ImageInfo.h"
#import "GifCreationManager.h"
#import "AnimatedItemCell.h"

static int AnimationList_DeleteAlert = 100;

@interface AnimationListController ()
@property (nonatomic, strong) IBOutlet UIBarButtonItem *cameraButton;
@property (nonatomic, strong) IBOutlet UIView *helpView;
@property (nonatomic, strong) IBOutlet UIWebView *wikiInfoView;
@property (nonatomic, strong) IBOutlet UIButton *informationButton;
@property (nonatomic, strong) NSString *navTitle;
@property (nonatomic, strong) FeedItem *itemPendingDelete;
@property (nonatomic, assign) BOOL beganDragging;

-(IBAction)informationAction:(id)sender;

- (void)configureCell:(UITableViewCell *)theCell atIndexPath:(NSIndexPath *)indexPath;


@end

@implementation AnimationListController


#pragma mark - Segue

- (UITableViewCell *)findCellFromView:(UIView *)v
{
	UIView *superView = [v superview];
	
	while (superView && ![superView isKindOfClass:[UITableViewCell class]])
	{
		superView = [superView superview];
	}
	return (UITableViewCell *)superView;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@"RedditPost"])
	{
		UITableViewCell *cell = [self findCellFromView:sender];
		if (cell)
		{
			NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
			FeedItem *item = [[self fetchedResultsController] objectAtIndexPath:indexPath];

			[(ImageInfo *)[segue destinationViewController] setItem:item];
		}
    }
    else if ([[segue identifier] isEqualToString:@"ViewRedditPost"])
	{
		UITableViewCell *cell = [self findCellFromView:sender];
		if (cell)
		{
			NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
			FeedItem *item = [[self fetchedResultsController] objectAtIndexPath:indexPath];
			
			[(ImgurWebViewController *)[segue destinationViewController] setItem:item];
		}
    }
    else if ([[segue identifier] isEqualToString:@"CameraSegue"])
	{
    }
}

#pragma mark - Actions

-(IBAction)informationAction:(id)sender
{
	if (self.informationButton.hidden)
	{
		return;
	}
	
	__block CGRect frm = self.view.frame;
	__block CGRect offscreenFrm = CGRectMake(0, -1 * frm.size.height, frm.size.width, frm.size.height);
	
	if (self.wikiInfoView.hidden)
	{
		[self.wikiInfoView.scrollView scrollRectToVisible:CGRectMake(0, 0, 100, 100) animated:NO];
		self.wikiInfoView.frame = offscreenFrm;
		self.wikiInfoView.hidden = NO;
		self.informationButton.enabled = NO;
		[UIView animateWithDuration:1.0 animations:^{
			self.wikiInfoView.frame = frm;
		} completion:^(BOOL finished) {
			self.informationButton.enabled = YES;
			self.informationButton.highlighted = YES;
		}];
	}
	else
	{
		self.informationButton.enabled = NO;
		self.informationButton.highlighted = NO;
		[UIView animateWithDuration:1.0 animations:^{
			self.wikiInfoView.frame = offscreenFrm;
		} completion:^(BOOL finished) {
			self.informationButton.enabled = YES;
			self.wikiInfoView.hidden = YES;
		}];
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag==AnimationList_DeleteAlert)
	{
		if (buttonIndex==1)
		{
			[self.itemPendingDelete remove]; // This removes and saves.
			[GifCreationManager removeEncodedImagesForEncoderID:self.itemPendingDelete.encoderID];
			self.itemPendingDelete = nil;
		}
		else if (buttonIndex==2)
		{
			[SVProgressHUD showWithStatus:@"Deleting..." maskType:SVProgressHUDMaskTypeGradient];
			[ImgurIOS deleteImageWithHashToken:self.itemPendingDelete.imgur.deletehash deleteComplete:^(BOOL success) {
				
				[self.itemPendingDelete remove]; // This removes and saves.
				[GifCreationManager removeEncodedImagesForEncoderID:self.itemPendingDelete.encoderID];
				self.itemPendingDelete = nil;
				[SVProgressHUD dismiss];
			}];
		}
		else
		{
			self.itemPendingDelete = nil;
		}
	}
}

#pragma mark - Help Wiki

-(void)mainThreadEnableHelp:(NSString *)helpHtml
{
	self.informationButton.hidden = NO;
	[self.wikiInfoView loadHTMLString:helpHtml baseURL:[NSURL URLWithString:@"https://github.com/dpedley/creeper/wiki/"]];
}

-(void)backgroundLoadHelpWiki
{
	// TODO: make the v1.0 in the follow read form the app bundle.
	NSString *baseWiki = @"creeper_help_v1.0";
	NSString *urlString = [NSString stringWithFormat:@"https://github.com/dpedley/creeper/wiki/%@", baseWiki];
	NSString *wikiHTML = [NSString stringWithContentsOfURL:[NSURL URLWithString:urlString] encoding:NSUTF8StringEncoding error:nil];
	if (wikiHTML)
	{
		NSRange start = [wikiHTML rangeOfString:[NSString stringWithFormat:@"%@_begin", baseWiki]];
		NSRange end = [wikiHTML rangeOfString:[NSString stringWithFormat:@"%@_end", baseWiki]];
		
		if (start.location!=NSNotFound && end.location!=NSNotFound)
		{
			if ((start.location + start.length) < end.location)
			{
				NSRange wikiHelpRange = NSMakeRange((start.location + start.length), end.location - (start.location + start.length) );
				NSString *wikiHelp = [wikiHTML substringWithRange:wikiHelpRange];
				[self performSelectorOnMainThread:@selector(mainThreadEnableHelp:) withObject:wikiHelp waitUntilDone:NO  ];
			}
		}
	}
}

#pragma mark - Utilities

-(void)delayedRemoveImagesForEncoderID:(NSString *)encoderID
{
	[GifCreationManager removeEncodedImagesForEncoderID:encoderID];
}

-(void)updateUI
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][0];
	int vidCount = [sectionInfo numberOfObjects];
	if (vidCount>0)
	{
		self.editButtonItem.enabled = YES;
	}
	else
	{
		self.editButtonItem.enabled = NO;
		if (self.tableView.isEditing)
		{
			[self.tableView setEditing:NO animated:YES];
		}
	}
}

-(void)animateVisibleCells
{
	NSArray *rows = [self.tableView visibleCells];
	for (UITableViewCell *cell in rows)
	{
		if ([cell isKindOfClass:[AnimatedItemCell class]])
		{
			CGRect translatedFrame = [self.tableView convertRect:[(AnimatedItemCell *)cell preview].frame fromView:cell];
			[(AnimatedItemCell *)cell setIsOnscreen:CGRectContainsRect(self.tableView.bounds, translatedFrame)];
		}
	}
}

#pragma mark - Object Lifecycle

- (void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.navTitle = self.title;
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
	[self.view addSubview:self.wikiInfoView];
	self.wikiInfoView.hidden = YES;
	
	self.informationButton.hidden = YES;
	[self performSelectorInBackground:@selector(backgroundLoadHelpWiki) withObject:nil];
	[self updateUI];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidDisappear:(BOOL)animated
{
	// Turn them all off
	NSArray *rows = [self.tableView visibleCells];
	for (UITableViewCell *cell in rows)
	{
		if ([cell isKindOfClass:[AnimatedItemCell class]])
		{
			[(AnimatedItemCell *)cell setIsOnscreen:NO];
		}
	}
}

-(void)viewWillAppear:(BOOL)animated
{
	[self.tableView reloadData];

	[self animateVisibleCells];
	
	[super viewWillAppear:animated];
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
	int vidCount = [sectionInfo numberOfObjects];
	return vidCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *cellID = @"RedditPostCell";
	
	FeedItem *entry = [self.fetchedResultsController objectAtIndexPath:indexPath];
	switch (entry.feedItemType)
	{
		case FeedItemType_Encoding:
			cellID = @"GifProcessingCell";
			break;
			
		case FeedItemType_Encoded:
		case FeedItemType_Uploading:
			cellID = @"ImageUploadingCell";
			break;
			
		case FeedItemType_Online:
			cellID = @"ImageOnlineCell";
			break;
			
		case FeedItemType_Reddit:
			cellID = @"RedditPostCell";
			break;
			
		default:
			break;
	}
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID forIndexPath:indexPath];
	[self configureCell:cell atIndexPath:indexPath];
	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	FeedItem *entry = [self.fetchedResultsController objectAtIndexPath:indexPath];

	switch (entry.feedItemType)
	{
		case FeedItemType_Encoding:
			return 80.0;
			break;
			
		default:
			break;
	}
	return 321.0;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
	int vidCount = [sectionInfo numberOfObjects];
	if (vidCount!=0)
	{
		return nil;
	}
	
	return self.helpView;
}

-(CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
	int vidCount = [sectionInfo numberOfObjects];
	if (vidCount!=0)
	{
		return 0;
	}
	
	return self.helpView.frame.size.height;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		FeedItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
		GifCreationManager *GCM = [GifCreationManager sharedInstance];
		
		switch (item.feedItemType)
		{
			case FeedItemType_Encoding:
			{
				NSString *itemEncoderID = item.encoderID;
				[GCM clearEncoder:itemEncoderID];
				[item remove]; // This removes and saves.
				[GifCreationManager removeEncodedImagesForEncoderID:itemEncoderID];
			}
				break;

			case FeedItemType_Encoded:
			case FeedItemType_Uploading:
			{
				[item remove]; // This removes and saves.
				[GifCreationManager removeEncodedImagesForEncoderID:item.encoderID];
			}
				break;
				
			case FeedItemType_Online:
			case FeedItemType_Reddit:
			{
				self.itemPendingDelete = item;
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Delete" message:@"Do you want to just remove it locally or delete from Imgur as well?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Local only", @"Also online version", nil];
				alert.tag = AnimationList_DeleteAlert;
				[alert show];
			}
				break;
				
			default:
				break;
		}
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView==self.tableView)
	{
		[self animateVisibleCells];
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView==self.tableView)
	{
		[self animateVisibleCells];
	}
}


#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"FeedItem" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error])
	{
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
		{
			FeedItem *item = [self.fetchedResultsController objectAtIndexPath:indexPath];
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
			
			if ([cell conformsToProtocol:@protocol(FeedItemCell)])
			{
				if ([(NSObject <FeedItemCell> *)cell isCorrectCellForItem:item])
				{
					[self configureCell:cell atIndexPath:indexPath];
				}
				else
				{
					[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
				}
			}
		}
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[self updateUI];
    [self.tableView endUpdates];
	[self animateVisibleCells];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)theCell atIndexPath:(NSIndexPath *)indexPath
{
	FeedItem *entry = [self.fetchedResultsController objectAtIndexPath:indexPath];

	if ([theCell conformsToProtocol:@protocol(FeedItemCell)])
	{
		[(UITableViewCell <FeedItemCell>*)theCell configureWithItem:entry];
	}
}

@end
