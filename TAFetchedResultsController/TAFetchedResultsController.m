//
//  TAFetchedResultsController.m
//  ShoppingList
//
//  Created by Timothy Armes on 13/06/2012.
//  Copyright (c) 2012 Timothy Armes. All rights reserved.
//

#import "TAFetchedResultsController.h"

#define DEBUG_TAFETCHEDRESULTSCONTROLLER 1

#if DEBUG_TAFETCHEDRESULTSCONTROLLER
#   define NSLog(...) NSLog(__VA_ARGS__);
#else 
#   define NSLog(...)
#endif

// Private interface

@interface TAFetchedResultsController ()

@property (strong, nonatomic) NSFetchedResultsController *nsFetchedResultsController;
@property (strong, nonatomic) NSEntityDescription *sectionEntityDescription;
@property (strong, nonatomic) NSString *propertyNameForSectionGrouping;
@property (strong, nonatomic) NSArray *previousMapping;

- (void)updateSections;
- (void)updateSectionMap;

- (NSArray *)fetchedSections;

@end

// We'll return an array of TASections when the user request the sections array...

@interface TASectionInfo : NSObject <TAFetchedResultsSectionInfo> 

@property (weak, nonatomic) TAFetchedResultsController *resultsController;
@property (nonatomic) NSUInteger sectionIndexInFetchedResults;

@end

@implementation TASectionInfo

@dynamic name;
@dynamic indexTitle;
@dynamic objects;
@dynamic numberOfObjects;

@synthesize theManagedObject = _theManagedObject;
@synthesize resultsController;
@synthesize sectionIndexInFetchedResults;

- (id)initWithManagedObject:(NSManagedObject *)managedObject;
{
    self = [super init];
    if (self)
    {
        _theManagedObject = managedObject;
        
    }
    
    return self;
}

- (NSString *)name
{    
    // Return the grouping name by default
    
    return (NSString *)[_theManagedObject valueForKey:resultsController.propertyNameForSectionGrouping];
}

- (NSArray *)objects
{
    // Check if there are any items for this row
    
    if (sectionIndexInFetchedResults == NSNotFound)
        return [[NSArray alloc] init];
    
    // Find the real section info
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[resultsController fetchedSections] objectAtIndex:sectionIndexInFetchedResults];
    return sectionInfo.objects;
}

- (NSUInteger)numberOfObjects
{
    // Check if there are any items for this row
    
    if (sectionIndexInFetchedResults == NSNotFound)
        return 0;
    
    // Find the real section info
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[resultsController fetchedSections] objectAtIndex:sectionIndexInFetchedResults];
    return sectionInfo.numberOfObjects;
}

@end

// Main implementation

@implementation TAFetchedResultsController

@synthesize nsFetchedResultsController = _nsFetchedResultsController;
@synthesize sectionEntityDescription = _sectionEntityDescription;
@synthesize sectionFetchRequest = _sectionFetchRequest;
@synthesize propertyNameForSectionGrouping = _propertyNameForSectionGrouping;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize sections = _sections;
@synthesize sectionIndexTitleKeyPath = _sectionIndexTitleKeyPath;

@synthesize previousMapping = _previousMapping;
@synthesize disabled = _disabled;
@synthesize delegate = _delegate;

@dynamic itemFetchRequest;
@dynamic cacheName;
@dynamic fetchedObjects;

- (id)initWithItemFetchRequest:(NSFetchRequest *)itemFetchRequest
           sectionFetchRequest:(NSFetchRequest *)sectionFetchRequest
          managedObjectContext:(NSManagedObjectContext *)context
        sectionGroupingKeyPath:(NSString *)sectionGroupingKeyPath
                     cacheName:(NSString *)name
{
    self = [super init];
        
    if (self)
    {
        // Create an instance of NSFetchResultsController
        
        self.nsFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:itemFetchRequest
                                                                              managedObjectContext:context
                                                                                sectionNameKeyPath:sectionGroupingKeyPath
                                                                                         cacheName:name];

        // The last part of the key path is the property in the section Entity that's used for the sort order.
        
        NSArray *keyNameParts = [sectionGroupingKeyPath componentsSeparatedByString:@"."];
        self.propertyNameForSectionGrouping = [keyNameParts objectAtIndex:keyNameParts.count - 1];
        
        _sectionFetchRequest = sectionFetchRequest;
        _managedObjectContext = context;
        
        // Set ourselves up as the delegate for NSFetchedResultsController
        
        self.nsFetchedResultsController.delegate = self;
        
        // We need to watch for model changes to the sections 
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDataModelChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:context];
    }
    
    return self;
}

- (void)dealloc
{
    self.nsFetchedResultsController = nil;

    // Remove our observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSFetchedResultsController 'overrides'

- (NSFetchRequest *)itemFetchRequest    
{
    return _nsFetchedResultsController.fetchRequest;
}

- (NSString *)cacheName
{
    return [_nsFetchedResultsController cacheName];
}

- (NSArray *)fetchedObjects
{
    return _nsFetchedResultsController.fetchedObjects;
}

+ (void)deleteCacheWithName:(NSString *)name
{
    [NSFetchedResultsController deleteCacheWithName:name];
}

- (BOOL)performFetch:(NSError **)error
{
    return [_nsFetchedResultsController performFetch:error];
}

- (NSArray *)sectionIndexTitles
{
    NSMutableArray *sectionIndexTitles;
    for (NSString *sectionTitle in [_sections valueForKey:_sectionIndexTitleKeyPath]) {
        if ([sectionTitle length] > 0) {
            NSString *firstLetter = [sectionTitle substringWithRange:[sectionTitle rangeOfComposedCharacterSequenceAtIndex:0]];
            if (![sectionIndexTitles containsObject:firstLetter]) {
                [sectionIndexTitles addObject:firstLetter];
            }
        }
    }
    return sectionIndexTitles;
}

- (NSInteger)sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)sectionIndex
{
    // we want to scroll even to empty sections
    return sectionIndex;
}

#pragma mark - Section mapping

- (void)updateSections
{
    NSLog(@"Updating section list");
    
    NSError *error = nil;
    [self.nsFetchedResultsController performFetch:&error];
    NSArray *sections = [_managedObjectContext executeFetchRequest:_sectionFetchRequest error:&error];
    if (sections == nil)
    {
        // Deal with error...
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    // Create a sections array that we can return to the caller
    
    NSMutableArray *sectionInfos = [NSMutableArray arrayWithCapacity:sections.count];
    
    for (NSManagedObject *sectionObject in sections) {
        TASectionInfo *taSectionInfo = [[TASectionInfo alloc] initWithManagedObject:sectionObject];
        taSectionInfo.resultsController = self;
        [sectionInfos addObject:taSectionInfo];
    }
    
    _sections = sectionInfos;
    
    [self updateSectionMap];
}

- (void)updateSectionMap
{
    
    // Reset the mapping
    
    for (TASectionInfo *si in _sections) {
        si.sectionIndexInFetchedResults = NSNotFound;        
    }
    
    // Create a mapping between the full section index and the section indexes returned by NSFetchResultsRequest (which
    // doesn't include any empty sections)
    
    if ([_sections count] > 0) {
        
        NSLog(@"Updating section map");
        
        int sectionIdx = 0;
        
        for (id <NSFetchedResultsSectionInfo> sectionInfo in [self fetchedSections]) {
            
            NSString *nameFromFetchResults = sectionInfo.name;
            
            // Find the corresponding section
            // NSFetchedResultsController only returns us the "name" as supplied by the "sectionNameKeyPath". This name
            // is normally used to both group and order the sections; it must be unique for each section. We can therefore
            // use this to locate the actual section entity. The order of the section array can be totally different to that
            // returned by NSFetchedResultsController :)
            
            NSLog(@"nameFromFetchResults: %@", nameFromFetchResults);
            
            BOOL found = NO;
            for (NSUInteger idx = 0; idx < _sections.count; idx++)
            {
                TASectionInfo *si = [_sections objectAtIndex:idx];
                NSString *propertyNameForSectionGrouping = [si.theManagedObject valueForKey:_propertyNameForSectionGrouping];
                if ([propertyNameForSectionGrouping isKindOfClass:[NSNumber class]]) {
                    propertyNameForSectionGrouping = [((NSNumber *)propertyNameForSectionGrouping) stringValue];
                }
                
                if ([propertyNameForSectionGrouping isEqualToString:nameFromFetchResults])
                {
                    si.sectionIndexInFetchedResults = sectionIdx;
                    found = YES;
                    break;
                }
            }
            
            if (!found)
            {
                [NSException raise:@"Section not found"
                            format:@"Section with value '%@' not found for property '%@' on section entity", sectionInfo.name, _propertyNameForSectionGrouping
                 ];
            }
            
            sectionIdx++;
        }
    }
}

- (BOOL)disabled
{
    return _disabled;
}

- (void)setDisabled:(BOOL)disabled  
{
    _disabled = disabled;
    
    if (!disabled)
    {
        [self updateSections];
    }
}

- (NSArray *)fetchedSections
{
    return _nsFetchedResultsController.sections;
}

- (id <NSFetchedResultsSectionInfo>)sectionInfoFromUITableViewControllerSectionIndex:(NSUInteger)section
{
    TASectionInfo *si = (TASectionInfo *)[_sections objectAtIndex:section];    
    NSUInteger sectionIndex = si.sectionIndexInFetchedResults;
    if (sectionIndex == NSNotFound) // Empty section
        return nil;
    
    return [[self fetchedSections] objectAtIndex:sectionIndex];
}

- (NSIndexPath *)convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:(NSIndexPath *)indexPath usingMapping:(NSArray *)mapping
{    
    TASectionInfo *si = (TASectionInfo *)[mapping objectAtIndex:(NSUInteger)indexPath.section];
    NSUInteger sectionIndex = si.sectionIndexInFetchedResults;
    if (sectionIndex == NSNotFound) // Empty section
        return nil;
    
    return [NSIndexPath indexPathForRow:indexPath.row inSection:(NSInteger)sectionIndex];
}

- (NSIndexPath *)convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:(NSIndexPath *)indexPath
{
    return [self convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:indexPath usingMapping:_sections];
}

- (NSIndexPath *)convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:(NSIndexPath *)indexPath usingMapping:(NSArray *)mapping
{    
    // Map the NSFetchedResults section index to the real section index
    
    int idx = 0;
    for (TASectionInfo *si in mapping) {
        NSUInteger sectionIndexInFetchedResults = si.sectionIndexInFetchedResults;
        if (sectionIndexInFetchedResults == (NSUInteger)indexPath.section)
        {
            return [NSIndexPath indexPathForRow:indexPath.row inSection:idx];
        }
        idx++;
    }
    
    // There really should be one, other wise we have a big problem
    
    [NSException raise:@"No key found for NSIndexPath supplied by NSFetchedResultsController"
                format:@"No key found for NSIndexPath supplied by NSFetchedResultsController when searching for [%ld, %ld]", (long)indexPath.section, (long)indexPath.row
     ];
    
    return NULL; // Stop compiler warning
}

- (NSIndexPath *)convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:(NSIndexPath *)indexPath
{    
    return [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:indexPath usingMapping:_sections];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath
{
    indexPath = [self convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:indexPath];
    if (!indexPath) // Empty section
        return nil;
    
    return [_nsFetchedResultsController objectAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForObject:(id)object
{
    NSIndexPath *indexPath = [_nsFetchedResultsController indexPathForObject:object];
    return [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:indexPath];
}

#pragma mark - NSFetchedResultsController delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if ([_delegate respondsToSelector:@selector(controllerWillChangeContent:)]) {
        [_delegate controllerWillChangeContent:self];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    if (_disabled)
        return;
    
    // This will be called if a row has been moved to a new section or if the last row has been deleted from a section
    //
    // This will cause the indexPath passed to didChangeObject to become out of sync. If we update the mapping now then
    // the deleted section will no longer be mapped and didChangeObject: won't be able to find the corresponding section
    // in the table (traditionally it would have been deleted from the table view at this point.
    // If we delay the remapping then we won't have a mapping for the the newly created section.
    //
    // We need to hold onto the old mapping (with the deleted section), remap, then use the appropriate table!

    // Note that in the case that several sections are deleted at once, we should only recreate the mapping once,
    // otherwise we'll be copying the mapping that would have already been updateded by the previous call
    // to this callback.
    
    if (_previousMapping == nil)
    {
        NSLog(@"Section changes detected. Storing copy of old mapping and creating a new map");
        
        NSMutableArray *prevMapping = [NSMutableArray arrayWithCapacity:[_sections count]];
        for (TASectionInfo *si in _sections) {
            TASectionInfo *newInfo = [[TASectionInfo alloc] initWithManagedObject:nil];
            newInfo.sectionIndexInFetchedResults = si.sectionIndexInFetchedResults;
            [prevMapping addObject:newInfo];
        }
        
        self.previousMapping = prevMapping;
    }

    [self updateSections];

    if ([_delegate respondsToSelector:@selector(controller:didChangeSection:atIndex:forChangeType:)]) {
        NSIndexPath *convertedIndexPath = [NSIndexPath indexPathForRow:0 inSection:(NSInteger)sectionIndex];
        if (type != NSFetchedResultsChangeInsert) {
            // The indexPath must exist - convert it...
            convertedIndexPath = [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:convertedIndexPath usingMapping:self.previousMapping];
            NSLog(@"Converted sectionIndex from %ld to %ld", (long)sectionIndex, (long)convertedIndexPath.section);
        }

        [_delegate controller:self
             didChangeSection:self.previousMapping[(NSUInteger)convertedIndexPath.section]
                      atIndex:(NSUInteger)convertedIndexPath.section
                forChangeType:type];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (_disabled)
        return;

    if ([_delegate respondsToSelector:@selector(controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:)]) {
        
        NSLog(@"TAFetchedResultsController has intercepted a delegate call to didChangeObject with indexPath [%ld, %ld] and newIndexPath [%ld, %ld].", (long)indexPath.section, (long)indexPath.row, (long)newIndexPath.section, (long)newIndexPath.row);
        
        // Use the previous mapping if there have been section changes
        
        NSArray *prevMapping = self.previousMapping;
        if (!prevMapping)
            prevMapping = _sections;
        
        // Convert the NSFetchedResultsController based index path to that used by the UITableViewController
        
        NSIndexPath *convertedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        NSIndexPath *convertedNewIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        
        if (type != NSFetchedResultsChangeInsert) {
            // The indexPath must exist - convert it...
            convertedIndexPath = [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:indexPath usingMapping:prevMapping];
            NSLog(@"Converted indexPath from [%ld, %ld] to [%ld, %ld]", (long)indexPath.section, (long)indexPath.row, (long)convertedIndexPath.section, (long)convertedIndexPath.row);
        }
        
        if (type == NSFetchedResultsChangeMove || type == NSFetchedResultsChangeInsert) {
            // newIndexPath must exist - convert it...
            convertedNewIndexPath = [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:newIndexPath usingMapping:_sections];
            NSLog(@"Converted newIndexPath from [%ld, %ld] to [%ld, %ld]", (long)newIndexPath.section, (long)newIndexPath.row, (long)convertedNewIndexPath.section, (long)convertedNewIndexPath.row);
        }
        
        // Pass this onto the user
        
        [_delegate controller:self
              didChangeObject:anObject
                  atIndexPath:convertedIndexPath
                forChangeType:type
                 newIndexPath:convertedNewIndexPath
         ];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (_disabled)
        return;

    NSLog(@"controllerDidChangeContent called - clearing previous mapping");
    self.previousMapping = nil;
    
    // Call the receiver's delegate
    
    if ([_delegate respondsToSelector:@selector(controllerDidChangeContent:)]) {
        [_delegate controllerDidChangeContent:self];
    }
}

#pragma mark - Model Change Handling

- (void)handleDataModelChange:(NSNotification *)notification;
{
    if (_disabled)
        return;

    NSSet *updatedObjects  = [[notification userInfo] objectForKey:NSUpdatedObjectsKey];
    NSSet *deletedObjects  = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
    NSSet *insertedObjects = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
    
    // We only care about changes to the Entity used for the sections
    
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSManagedObject *mo = (NSManagedObject *)evaluatedObject;
        return [mo.entity isKindOfEntity:[self.sectionFetchRequest entity]];
    }];
     
    updatedObjects  = [updatedObjects  filteredSetUsingPredicate:predicate];
    deletedObjects  = [deletedObjects  filteredSetUsingPredicate:predicate];
    insertedObjects = [insertedObjects filteredSetUsingPredicate:predicate];
 
    // If our fetch request isn't affected by the change then we return....
    
    if ([updatedObjects count] + [deletedObjects count] + [insertedObjects count] == 0)
        return;
    
    NSLog(@"Section changes detected, %lu deleted, %lu inserted, %lu updated", (unsigned long)[deletedObjects count], (unsigned long)[insertedObjects count], (unsigned long)[updatedObjects count]);
    
    // Tell the delegate that we're about to make changes
    
    if ([_delegate respondsToSelector:@selector(controllerWillChangeContent:)]) {
        [_delegate controllerWillChangeContent:self];
    }
    
    // A flag to see if [self updateSections] is needed
    BOOL hasSectionUpdated = NO;
    
    // Go through the list of changes to send
    if ([_delegate respondsToSelector:@selector(controller:didChangeSection:atIndex:forChangeType:)]) {
        
        // Tell the delegate about any deleted rows
        
        NSUInteger idx = 0;
        for (TASectionInfo *si in _sections) {
            if ([deletedObjects containsObject:si.theManagedObject]) {
                [_delegate controller:self didChangeSection:si atIndex:idx forChangeType:NSFetchedResultsChangeDelete];
            }
            idx++;
        }
        
        // Re-fetch the sections list (without the deleted sections) and update us internally
        //
        // Once we've done this the indexes of the sections will be correct for the sections to be inserted and modified
        [self updateSections];
		hasSectionUpdated = YES;
        
        idx = 0;
        for (TASectionInfo *si in _sections) {
            
            if ([updatedObjects containsObject:si.theManagedObject]) {
                [_delegate controller:self didChangeSection:si atIndex:idx forChangeType:NSFetchedResultsChangeUpdate];
            }
            
            if ([insertedObjects containsObject:si.theManagedObject]) {
                [_delegate controller:self didChangeSection:si atIndex:idx forChangeType:NSFetchedResultsChangeInsert];
            }
            idx++;
        }
    }
    
    // If delegate does not response to controller:didChangeSection:atIndex:forChangeType:, [self updateSections] explicitly
    if (!hasSectionUpdated) {
        [self updateSections];
    }
    
    // Tell the delegate that we've finished making changes
    
    if ([_delegate respondsToSelector:@selector(controllerDidChangeContent:)]) {
        [_delegate controllerDidChangeContent:self];
    }
}

@end
