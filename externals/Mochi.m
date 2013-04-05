//
//  Mochi.m
//
//  Created by Douglas Pedley on 5/27/10.
//

#import "Mochi.h"

#define MOCHI_DOCUMENTS_DIRECTORY [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]

static Mochi *sharedMochi;
static NSDictionary *mochiClasses;

@interface Mochi (MochiPrivateFunctions)


+(NSURL *)defaultSettingsURL;

@end

@implementation Mochi (MochiPrivateFunctions)

+(NSURL *)defaultSettingsURL
{
	NSString *urlPath = [MOCHI_DOCUMENTS_DIRECTORY stringByAppendingPathComponent:@"mochi.plist"];
	return [NSURL fileURLWithPath:urlPath];
}

@end

@implementation Mochi

@synthesize managedObjectModel, managedObjectContext, persistentStoreCoordinator, dataFile, dataModel, disableUndoManager;

#pragma mark Initial settings
+(void)settingsFromDictionary:(NSDictionary *)settingsDictionary
{
	if (sharedMochi) 
	{
		sharedMochi = nil;
	}
	
	sharedMochi = [[Mochi alloc] initWithDictionary:settingsDictionary];
	
	if (mochiClasses)
	{
		mochiClasses = nil;
	}
	
	NSDictionary *classMappings = [settingsDictionary objectForKey:@"classMappings"];
	if (classMappings!=nil)
	{
		NSArray *allKeys = [classMappings allKeys];
		NSMutableDictionary *buildMochi = [NSMutableDictionary dictionaryWithCapacity:[allKeys count]];
		for (NSString *key in allKeys)
		{
			NSDictionary *classSettingsDict = [classMappings objectForKey:key];
			
			if (classSettingsDict)
			{
				Mochi *classMochi = [[Mochi alloc] initWithDictionary:classSettingsDict];
				[buildMochi setObject:classMochi forKey:key];
			}
		}
		mochiClasses = [[NSDictionary alloc] initWithDictionary:buildMochi]; 
	}
}

-(id)initWithDictionary:(NSDictionary *)settings
{
	if ([super init])
	{
		NSString *database  = [[settings valueForKey:@"database"] stringByAppendingString:@".sqlite"];
		NSString *model = [settings valueForKey:@"model"];
		NSNumber *bDisableUndoManager = [settings valueForKey:@"disableUndoManager"];
		
		self.dataFile = database;
		self.dataModel = model;
		
		if (bDisableUndoManager!=nil) 
		{
			self.disableUndoManager = [bDisableUndoManager boolValue];
		}
		else 
		{
			self.disableUndoManager = NO;
		}		
	}
	
	return self;
}

-(void)defaultDatabaseFromBundle
{
	[self defaultDatabaseFromBundle:NO];
}

-(void)defaultDatabaseFromBundle:(BOOL)overwriteIfExists
{
    NSString *toDB = [MOCHI_DOCUMENTS_DIRECTORY stringByAppendingPathComponent:self.dataFile];
    NSString *fromDB = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:self.dataFile];
	
	// Only copy the default database if it doesn't already exist
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (!overwriteIfExists && [fileManager fileExistsAtPath:toDB]) 
	{
		return;
	}
	
	
    NSError *error;
    if (![fileManager copyItemAtPath:fromDB toPath:toDB error:&error]) 
	{
        NSLog(@"Couldn't copy database from application bundle \n[%@].", [error localizedDescription]);
    }
}

#pragma mark NSManagedObjectContext, NSPersistentStoreCoordinator, NSManagedObjectModel property accessors  

-(NSManagedObjectContext *)managedObjectContext 
{
    if (managedObjectContext!=nil) 
	{
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	
	if (coordinator!=nil) 
	{
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
		if (disableUndoManager) { [managedObjectContext setUndoManager:nil]; }
    }
	
    return managedObjectContext;
}

-(NSManagedObjectModel*)managedObjectModel 
{
	if (managedObjectModel) 
	{
		return managedObjectModel;
	}
	
	NSString *fileResource = [[NSBundle bundleForClass:[Mochi class]] pathForResource:self.dataModel ofType:@"mom"];
	if (fileResource==nil)
	{
		fileResource = [[NSBundle bundleForClass:[Mochi class]] pathForResource:self.dataModel ofType:@"momd"];
	}
	NSURL *momFile = [NSURL fileURLWithPath:fileResource];
	managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:momFile];
	return managedObjectModel;
}

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{
    if (persistentStoreCoordinator != nil) 
	{
        return persistentStoreCoordinator;
    }
	
	NSString *mochiDir = [MOCHI_DOCUMENTS_DIRECTORY stringByAppendingPathComponent:self.dataFile];
    NSURL *pscUrl = [NSURL fileURLWithPath:mochiDir];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
    
	NSError *error;
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:pscUrl options:options error:&error])
	{
		NSLog(@"Error adding persistant store coordinator %@", [error localizedDescription]);
    }
	
    return persistentStoreCoordinator;
}

#pragma mark Singleton Helpers

+(id)sharedMochi 
{ 
	@synchronized(sharedMochi) 
	{
		if (sharedMochi == nil) 
		{
			NSDictionary *defaultSettingsDict = [NSDictionary dictionaryWithContentsOfURL:[self defaultSettingsURL]];
			[self settingsFromDictionary:defaultSettingsDict];
		}
	}
	return sharedMochi;
}


+(id)mochiForClass:(Class)mochiClass
{
	id ret = [mochiClasses objectForKey:[mochiClass description]];
	if (ret==NULL) 
	{
		return [self sharedMochi];
	}
	return ret;
}

-(id)copyWithZone:(NSZone *)zone 
{ 
	return self; 
} 

@end



/*
 
 These are the Mochi Managed Object Category Additions
 they are helpers to do the common database load, save, search type of functionality
 
 */

static NSMutableDictionary *mochiClassIDs = nil;

@implementation NSManagedObject (Mochi)

#pragma mark -
#pragma mark Configuration elements

+(void)mochiSettingsFromDictionary:(NSDictionary *)settingsDictionary
{
	NSMutableDictionary *buildMochi = nil;
	Mochi *classMochi = [[Mochi alloc] initWithDictionary:settingsDictionary];
	if (mochiClasses==nil)
	{
		buildMochi = [NSMutableDictionary dictionaryWithObject:classMochi forKey:[self description]];
	}
	else 
	{
		buildMochi = [NSDictionary dictionaryWithDictionary:mochiClasses];
		[buildMochi setObject:classMochi forKey:[self description]];
	}
	mochiClasses = [[NSDictionary alloc] initWithDictionary:buildMochi]; 
}

+(NSEntityDescription *)mochiEntityDescription
{
	return [NSEntityDescription entityForName:[self description] inManagedObjectContext:[[Mochi mochiForClass:[self class]] managedObjectContext]];
}

#pragma mark -
#pragma mark Index field name property

+(NSString *)indexName
{
	return [mochiClassIDs valueForKey:[self description]];
}

+(void)setIndexName:(NSString *)value
{
	if (mochiClassIDs==nil) 
	{
		mochiClassIDs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:value, [self description], nil];
	}
	else 
	{
		[mochiClassIDs setValue:value forKey:[self description]];
	}
}

#pragma mark -
#pragma mark Object lifecycle, Add, Remove, Save

+(id)addNew 
{
	return [NSEntityDescription insertNewObjectForEntityForName:[self description] inManagedObjectContext:[[Mochi mochiForClass:[self class]] managedObjectContext]];
}

+(id)addNewWithIndex:(NSNumber *)ID 
{
	id newObject = [self addNew];
	NSString *fieldNameID = [self indexName];
	if (fieldNameID!=nil)
	{
		[(NSManagedObject *)newObject setValue:ID forKey:fieldNameID];
	}
	return newObject;
}

+(void)save 
{
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	NSError *error;
	[mochi.managedObjectContext save:&error];
	mochi.lastError = error;
}

-(void)remove
{
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	[mochi.managedObjectContext deleteObject:self];
	NSError *error;
	[mochi.managedObjectContext save:&error];
	mochi.lastError = error;
}

+(void)removeAll
{
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	NSArray *all = [self allObjects];
	for (id currentObject in all) 
	{
		[mochi.managedObjectContext deleteObject:currentObject];
	}
	NSError *error;
	[mochi.managedObjectContext save:&error];
	mochi.lastError = error;
}

+(id)findOrCreateWithDictionary:(NSDictionary *)createDict
{
	NSManagedObject *targetObject = nil;
	NSString *ndxName = [self indexName];
	if (ndxName!=nil)
	{
		NSValue *ndxValue = [createDict objectForKey:ndxName];
		if (ndxValue!=nil)
		{
			targetObject = [self withAttributeNamed:ndxName matchingValue:ndxValue];
			
			if (targetObject==nil)
			{
				targetObject = [self addNewWithIndex:ndxValue];
			}
		}
	}
	
	if (targetObject==nil)
	{
		targetObject = [self addNew];
	}
	
	[targetObject setValuesForKeysWithDictionary:createDict];
	return targetObject;
}

#pragma mark -

+(int)count
{
	NSFetchRequest *req = [[NSFetchRequest alloc] init];
	req.entity = [self mochiEntityDescription];
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	NSError *error;
	return [[mochi managedObjectContext] countForFetchRequest:req error:&error];
	mochi.lastError = error;
}

#pragma mark -
#pragma mark Retrieval

+(id)withMatchingIndex:(NSValue *)indexValue
{
	NSString *ndxName = [self indexName];
	if (ndxName!=nil)
	{
		return [self withAttributeNamed:ndxName matchingValue:indexValue];
	}
	return nil;
}

+(NSArray *)allObjects
{
	NSFetchRequest *req = [[NSFetchRequest alloc] init];
	req.entity = [self mochiEntityDescription];
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	NSError *error;
	NSArray *all = [[[Mochi mochiForClass:[self class]] managedObjectContext] executeFetchRequest:req error:&error];
	mochi.lastError = error;
	return all;
}

+(id)arrayWithAttributeNamed:(NSString *)field matchingValue:(id)value
{
	NSFetchRequest *req = [[NSFetchRequest alloc] init];
	req.entity = [self mochiEntityDescription];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%@ = $V", field, nil]];
	predicate = [predicate predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:value forKey:@"V"]];
	[req setPredicate:predicate];
	Mochi *mochi = [Mochi mochiForClass:[self class]];
	NSError *error;
	NSArray *fetchResponse = [[mochi managedObjectContext] executeFetchRequest:req error:&error];
	mochi.lastError = error;
	if ((fetchResponse != nil) || ([fetchResponse count]>0))
	{
		return [NSArray arrayWithArray:fetchResponse];
	}
	return nil;
}

+(id)withAttributeNamed:(NSString *)field matchingValue:(id)value
{
	NSArray *all = [self arrayWithAttributeNamed:field matchingValue:value];
	if ((all==nil) || ([all count]==0)) 
	{
		return nil;
	}
	return [all objectAtIndex:0];
}

#pragma mark -
#pragma mark Fetch Result Controller for retrieval


+(NSFetchedResultsController *)fetchResultsControllerForAllSorted:(NSArray *)sortDescriptors
{
    // Create the fetch request for the entity.
    NSFetchRequest *req = [[NSFetchRequest alloc] init];
    [req setEntity:[self mochiEntityDescription]];
    
    // TODO move this into a setting in the mochi setup dictionary
    [req setFetchBatchSize:20];
	
	if (sortDescriptors)
	{
		req.sortDescriptors = sortDescriptors;
	}
	
	Mochi *classMochi = [Mochi mochiForClass:[self class]];
	
	// TODO check out section key path etc.
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:req 
																				 managedObjectContext:[classMochi managedObjectContext] 
																				   sectionNameKeyPath:nil 
																							cacheName:@"Root"];
    
    return controller;
}

+(NSFetchedResultsController *)fetchResultsControllerForAllObjects
{
	return [self fetchResultsControllerForAllSorted:nil];
}

+(NSFetchedResultsController *)fetchResultsControllerWithAttributeNamed:(NSString *)field matchingValue:(id)value
{
	NSFetchRequest *req = [[NSFetchRequest alloc] init];
	req.entity = [self mochiEntityDescription];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:[NSString stringWithFormat:@"%@ = $V", field, nil]];
	predicate = [predicate predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:value forKey:@"V"]];
	[req setPredicate:predicate];
	
    // TODO move this into a setting in the mochi setup dictionary
    [req setFetchBatchSize:20];
	
	Mochi *classMochi = [Mochi mochiForClass:[self class]];
	
	// TODO check out section key path etc.
    NSFetchedResultsController *controller = [[NSFetchedResultsController alloc] initWithFetchRequest:req 
																				 managedObjectContext:[classMochi managedObjectContext] 
																				   sectionNameKeyPath:nil 
																							cacheName:@"Root"];
	
    return controller;
}

#pragma mark undefined keys override default behavior
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return NULL;
}



@end

