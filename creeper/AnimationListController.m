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
#import "RedditWebViewController.h"
#import "GifProcessingCell.h"
#import "ImgurEntry.h"
#import "FeedItem.h"
#import "CreeperDataExtensions.h"
#import "ImgurIOS.h"
#import "iOSRedditAPI.h"
#import "RedditPostSubmit.h"
#import "ImgurSubmit.h"
#import "GifCreationManager.h"
#import "AnimatedItemCell.h"
#import "RedditPostCell.h"
#import "ExternalServices.h"

static int AnimationList_DeleteAlert = 100;
static double AnimationListVelocityFast = 900.0f;

typedef enum
{
	AnimationListFilter_CreeperApp = 0,
	AnimationListFilter_LocalStorage = 1
} AnimationListFilter;

@interface AnimationListController ()
@property (nonatomic, strong) IBOutlet UISegmentedControl *tableFilter;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *cameraButton;
@property (nonatomic, strong) IBOutlet UIView *helpView;
@property (nonatomic, strong) IBOutlet UIWebView *wikiInfoView;
@property (nonatomic, strong) IBOutlet UIButton *informationButton;
@property (nonatomic, strong) NSString *navTitle;
@property (nonatomic, strong) FeedItem *itemPendingDelete;
@property (nonatomic, assign) BOOL beganDragging;
@property (nonatomic, readonly) AnimationListFilter currentFilter;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSFetchedResultsController *redditResultsController;

-(IBAction)informationAction:(id)sender;
-(IBAction)tableFilterAction:(id)sender;

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

			[(RedditPostSubmit *)[segue destinationViewController] setItem:item];
		}
    }
    else if ([[segue identifier] isEqualToString:@"ViewRedditPost"])
	{
		UITableViewCell *cell = [self findCellFromView:sender];
		if (cell)
		{
			NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
			if (self.currentFilter==AnimationListFilter_LocalStorage)
			{
				FeedItem *item = [[self fetchedResultsController] objectAtIndexPath:indexPath];
				[(RedditWebViewController *)[segue destinationViewController] configureWithReddit:item.reddit];
			}
			else if (self.currentFilter==AnimationListFilter_CreeperApp)
			{
				RedditPost *rp = [[self redditResultsController] objectAtIndexPath:indexPath];
				[(RedditWebViewController *)[segue destinationViewController] configureWithReddit:rp];
			}
			
		}
    }
	if ([[segue identifier] isEqualToString:@"ImgurUpload"])
	{
		UITableViewCell *cell = [self findCellFromView:sender];
		if (cell)
		{
			NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
			FeedItem *item = [[self fetchedResultsController] objectAtIndexPath:indexPath];
			
			[(ImgurSubmit *)[segue destinationViewController] setItem:item];
		}
    }
    else if ([[segue identifier] isEqualToString:@"CameraSegue"])
	{
    }
}

#pragma mark - Actions

-(IBAction)tableFilterAction:(id)sender
{
	if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		self.navigationItem.leftBarButtonItem = nil;
		UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
		refreshControl.tintColor = [UIColor grayColor];
		[refreshControl addTarget:self action:@selector(refreshControlValueChanged) forControlEvents:UIControlEventValueChanged];
		self.refreshControl = refreshControl;
	}
	else
	{
		self.navigationItem.leftBarButtonItem = self.editButtonItem;
		self.refreshControl = nil;
	}
	
	[self.tableView reloadData];
	[self animateVisibleCells];
	[[NSUserDefaults standardUserDefaults] setInteger:self.tableFilter.selectedSegmentIndex forKey:@"CreeperDefaults_FeedTableFilter"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

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
			NSString *theEncoderID = self.itemPendingDelete.encoderID;
			[[GifCreationManager sharedInstance] clearEncoder:theEncoderID];
			[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
				[self.itemPendingDelete deleteInContext:localContext];
			} completion:^(BOOL success, NSError *error) {
				[GifCreationManager removeEncodedImagesForEncoderID:theEncoderID];
				self.itemPendingDelete = nil;
			}];
		}
		else if (buttonIndex==2)
		{
			[SVProgressHUD showWithStatus:@"Deleting..." maskType:SVProgressHUDMaskTypeGradient];
			
			__block int removeCompletions = 0;
			__weak AnimationListController *blockSelf = self;
			__block NSString *theEncoderID = [NSString stringWithString:self.itemPendingDelete.encoderID];
			void (^deleteBothOnlineCompletion)(BOOL) = ^(BOOL success) {
				removeCompletions++;
				if (removeCompletions==2)
				{
					[MagicalRecord saveUsingCurrentThreadContextWithBlock:^(NSManagedObjectContext *localContext) {
						[blockSelf.itemPendingDelete deleteInContext:localContext];
					} completion:^(BOOL success, NSError *error) {
						[GifCreationManager removeEncodedImagesForEncoderID:theEncoderID];
						blockSelf.itemPendingDelete = nil;
						[SVProgressHUD dismiss];
					}];
				}
			};
			
			if (self.itemPendingDelete.reddit)
			{
				[[iOSRedditAPI shared] deleteByName:self.itemPendingDelete.reddit.redditName parentVC:self deleted:deleteBothOnlineCompletion];
			}
			else
			{
				removeCompletions = 1;
			}
			[ImgurIOS deleteImageWithHashToken:self.itemPendingDelete.imgur.deletehash deleteComplete:deleteBothOnlineCompletion];
		}
		else
		{
			self.itemPendingDelete = nil;
		}
	}
}

#pragma mark - Properties

-(AnimationListFilter)currentFilter
{
	return (AnimationListFilter)self.tableFilter.selectedSegmentIndex;
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

-(CGRect)translatedCell:(AnimatedItemCell *)cell
{
    static CGRect basePreviewFrame;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect origFrm = [cell preview].frame;
        CGFloat frmBorder = origFrm.size.width * 0.2f;
        basePreviewFrame = CGRectMake(origFrm.origin.x + frmBorder, origFrm.origin.y + frmBorder, origFrm.size.width - (2 * frmBorder), origFrm.size.height - (2 * frmBorder));
    });
    return [self.tableView convertRect:basePreviewFrame fromView:cell];
}

-(void)animateVisibleCells
{
	NSArray *rows = [self.tableView visibleCells];
	for (UITableViewCell *cell in rows)
	{
		if ([cell isKindOfClass:[AnimatedItemCell class]])
		{
			CGRect translatedRect = [self translatedCell:(AnimatedItemCell *)cell];
			BOOL cellIsVisible = CGRectIntersectsRect(self.tableView.bounds, translatedRect);
			
            
			if (!cellIsVisible)
			{
				cellIsVisible = CGRectContainsRect(self.tableView.bounds, translatedRect);
			}
            
//            NSLog(@"cell: %@ %@ %@ %@", [(RedditPostCell *)cell reddit].redditTitle, cellIsVisible?@"on":@"off", NSStringFromCGRect(translatedRect), NSStringFromCGRect(self.tableView.bounds));
            if (cellIsVisible)
            {
                NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                if (![(AnimatedItemCell *)cell animationLoaded])
                {
                    [self configureCell:cell atIndexPath:indexPath];
                }
            }
            
			[(AnimatedItemCell *)cell setIsOnscreen:cellIsVisible];
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
	[self.view addSubview:self.wikiInfoView];
	self.wikiInfoView.hidden = YES;
	
	self.informationButton.hidden = YES;
	[self performSelectorInBackground:@selector(backgroundLoadHelpWiki) withObject:nil];
	[self updateUI];
	
	int tFilter = [[NSUserDefaults standardUserDefaults] integerForKey:@"CreeperDefaults_FeedTableFilter"];
	if ( (tFilter>0) || (tFilter<[self.tableFilter numberOfSegments]) )
	{
		[self.tableFilter setSelectedSegmentIndex:tFilter];
	}
	
	if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		self.navigationItem.leftBarButtonItem = nil;
		
		UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
		refreshControl.tintColor = [UIColor grayColor];
		[refreshControl addTarget:self action:@selector(refreshControlValueChanged) forControlEvents:UIControlEventValueChanged];
		self.refreshControl = refreshControl;
	}
	else
	{
		self.navigationItem.leftBarButtonItem = self.editButtonItem;
		self.refreshControl = nil;
	}

	// load the latest posts
	[[iOSRedditAPI shared] loadSubreddit:@"creeperapp" completion:^(NSArray *postArray) {}];
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
	[super viewWillAppear:animated];
    static BOOL firstViewWillAppear = YES;
    if (!firstViewWillAppear)
    {
        [self.tableView reloadData];
    }
    firstViewWillAppear = NO;
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self animateVisibleCells];
}

#pragma mark - Table View

-(void)refreshControlValueChanged
{
	__weak AnimationListController *blockSelf = self;
	[[iOSRedditAPI shared] loadSubreddit:@"creeperapp" completion:^(NSArray *postArray) {
        [blockSelf.refreshControl endRefreshing];
	}];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (self.currentFilter==AnimationListFilter_LocalStorage)
	{
		return [[self.fetchedResultsController sections] count];
	}
	else if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		return [[self.redditResultsController sections] count];
	}
	
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.currentFilter==AnimationListFilter_LocalStorage)
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
		int vidCount = [sectionInfo numberOfObjects];
		return vidCount;
	}
	else if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		id <NSFetchedResultsSectionInfo> sectionInfo = [self.redditResultsController sections][section];
		int vidCount = [sectionInfo numberOfObjects];
		return vidCount;
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *cellID = @"RedditPostCell";
	
	if (self.currentFilter==AnimationListFilter_LocalStorage)
	{
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
	}
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID forIndexPath:indexPath];
	[self configureCell:cell atIndexPath:indexPath];
	return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 340.0;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		return nil;
	}
	
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
	if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		return 0;
	}
	
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
	return (self.currentFilter==AnimationListFilter_LocalStorage);
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
				[MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
					FeedItem *localItem = [FeedItem withEncoderID:itemEncoderID inContext:localContext];
					[localItem deleteInContext:localContext];
				} completion:^(BOOL success, NSError *error) {
					[GifCreationManager removeEncodedImagesForEncoderID:itemEncoderID];
				}];
			}
				break;

			case FeedItemType_Encoded:
			case FeedItemType_Uploading:
			{
				NSString *itemEncoderID = item.encoderID;
				[MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
					FeedItem *localItem = [FeedItem withEncoderID:itemEncoderID inContext:localContext];
					[localItem deleteInContext:localContext];
				} completion:^(BOOL success, NSError *error) {
					[GifCreationManager removeEncodedImagesForEncoderID:itemEncoderID];
				}];
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

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

// This method just used for velocity.
-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if (scrollView==self.tableView)
	{
		//Simple velocity calculation
		NSTimeInterval curCallTime = [NSDate timeIntervalSinceReferenceDate];
		NSTimeInterval timeDelta = curCallTime - prevCallTime;
		double curCallOffset = self.tableView.contentOffset.y;
		double offsetDelta = curCallOffset - prevCallOffset;
		velocity = fabs(offsetDelta / timeDelta);
//		DLog(@"Velocity: %f", velocity);
		prevCallTime = curCallTime;
		prevCallOffset = curCallOffset;
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView==self.tableView && velocity<AnimationListVelocityFast)
	{
		[self animateVisibleCells];
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView==self.tableView)
	{
        velocity = 0;
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
	
	// A lil predicate to limit the feed item typed
	NSPredicate *mustBeSaved = [NSPredicate predicateWithFormat:@"itemType != %d", (int)FeedItemType_Unsaved];
	[fetchRequest setPredicate:mustBeSaved];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timestamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"FeedItemCache"];
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

- (NSFetchedResultsController *)redditResultsController
{
    if (_redditResultsController != nil) {
        return _redditResultsController;
    }
	
#warning remove cache deletion
	[NSFetchedResultsController deleteCacheWithName:@"RedditPostCache"];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"RedditPost" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
	NSPredicate *orderPredicate = [NSPredicate predicateWithFormat:@"hotOrder >= %d", 0];
	NSPredicate *validationPredicate = [NSPredicate predicateWithFormat:@"validationString != NULL"];
	NSPredicate *andPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:orderPredicate, validationPredicate, nil]];
	[fetchRequest setPredicate:andPredicate];
	
    // Edit the sort key as appropriate.
    NSSortDescriptor *createdDescriptor = [[NSSortDescriptor alloc] initWithKey:@"hotOrder" ascending:YES];
    NSArray *sortDescriptors = @[createdDescriptor];
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"RedditPostCache"];
    aFetchedResultsController.delegate = self;
    self.redditResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.redditResultsController performFetch:&error])
	{
		// Replace this implementation with code to handle the error appropriately.
		// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _redditResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	if (((self.currentFilter==AnimationListFilter_CreeperApp) && (controller==self.redditResultsController)) ||
		((self.currentFilter==AnimationListFilter_LocalStorage) && (controller==self.fetchedResultsController)))
	{
		[self.tableView beginUpdates];
	}
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
	if (((self.currentFilter==AnimationListFilter_CreeperApp) && (controller==self.redditResultsController)) ||
		((self.currentFilter==AnimationListFilter_LocalStorage) && (controller==self.fetchedResultsController)))
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
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
	if (((self.currentFilter==AnimationListFilter_CreeperApp) && (controller==self.redditResultsController)) ||
		((self.currentFilter==AnimationListFilter_LocalStorage) && (controller==self.fetchedResultsController)))
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
				if (self.currentFilter==AnimationListFilter_LocalStorage)
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
				else if (self.currentFilter==AnimationListFilter_CreeperApp)
				{
					UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
					
					if ([cell isKindOfClass:[RedditPostCell class]])
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
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	if (((self.currentFilter==AnimationListFilter_CreeperApp) && (controller==self.redditResultsController)) ||
		((self.currentFilter==AnimationListFilter_LocalStorage) && (controller==self.fetchedResultsController)))
	{
		[self updateUI];
		[self.tableView endUpdates];
		[self animateVisibleCells];
	}
}

- (void)configureCell:(UITableViewCell *)theCell atIndexPath:(NSIndexPath *)indexPath
{
	AnimatedItemCellRenderDetailLevel lvl = (velocity < AnimationListVelocityFast) ? AnimatedItemCellRenderDetailLevel_Full : AnimatedItemCellRenderDetailLevel_Minimal;
	if (self.currentFilter==AnimationListFilter_LocalStorage)
	{
		FeedItem *entry = [self.fetchedResultsController objectAtIndexPath:indexPath];

		if ([theCell conformsToProtocol:@protocol(FeedItemCell)])
		{
			[(UITableViewCell <FeedItemCell>*)theCell configureWithItem:entry detailLevel:lvl];
		}
	}
	else if (self.currentFilter==AnimationListFilter_CreeperApp)
	{
		RedditPost *entry = [self.redditResultsController objectAtIndexPath:indexPath];
		[(RedditPostCell *)theCell configureWithReddit:entry detailLevel:lvl];
	}
}

@end
