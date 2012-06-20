//
//  TAFetchedResultsController.m
//  ShoppingList
//
//  Created by Timothy Armes on 13/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TAFetchedResultsController.h"
#import "TADelegateInterceptor.h"

#define DEBUG_TAFETCHEDRESULTSCONTROLLER 0

#if DEBUG_TAFETCHEDRESULTSCONTROLLER
#   define NSLog(...) NSLog(__VA_ARGS__);
#else 
#   define NSLog(...)
#endif

// Private interface

@interface TAFetchedResultsController ()

@property (strong, nonatomic) NSEntityDescription *sectionEntityDescription;
@property (strong, nonatomic) NSFetchRequest *sectionFetchRequest;
@property (strong, nonatomic) NSString *propertyNameForSectionGrouping;
@property (strong, nonatomic) NSManagedObjectContext *context;
@property (strong, nonatomic) TADelegateInterceptor *delegateInterceptor;
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
    // Ask the user for a name
    
    if ([(NSObject *)resultsController.delegate respondsToSelector:@selector(controller:sectionNameForObject:)]) {
        return [resultsController.delegate controller:resultsController sectionNameForObject:_theManagedObject];
    }
    
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

@synthesize sectionEntityDescription = _sectionEntityDescription;
@synthesize sectionFetchRequest = _sectionFetchRequest;
@synthesize propertyNameForSectionGrouping = _propertyNameForSectionGrouping;
@synthesize context = _context;
@synthesize allSections = _allSections;
@synthesize delegateInterceptor = _delegateInterceptor;
@synthesize previousMapping = _previousMapping;
@dynamic delegate;

- (id)initWithItemFetchRequest:(NSFetchRequest *)itemFetchRequest
           sectionFetchRequest:(NSFetchRequest *)sectionFetchRequest
          managedObjectContext:(NSManagedObjectContext *)context
        sectionGroupingKeyPath:(NSString *)sectionGroupingKeyPath
                     cacheName:(NSString *)name
{
    self = [super initWithFetchRequest:itemFetchRequest managedObjectContext:context sectionNameKeyPath:sectionGroupingKeyPath cacheName:name];
    
    if (self)
    {
        // The last part of the key path is the property in the section Entity that's used for the sort order.
        NSArray *keyNameParts = [sectionGroupingKeyPath componentsSeparatedByString:@"."];
        self.propertyNameForSectionGrouping = [keyNameParts objectAtIndex:keyNameParts.count - 1];
        
        self.sectionFetchRequest = sectionFetchRequest;
        self.context = context;
        
        // We intercept delegate calls so that we can modify the indexPath
        
        self.delegateInterceptor = [[TADelegateInterceptor alloc] init];
        [_delegateInterceptor setMiddleMan:self];
        [super setDelegate:(id)_delegateInterceptor];
    }
    
    return self;
}

#pragma mark - Section mapping

- (void)updateSections
{
    NSLog(@"Updating section list");
    
    NSError *error = nil;
    NSArray *sections = [_context executeFetchRequest:_sectionFetchRequest error:&error];
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
    
    self.allSections = sectionInfos;
    
    [self updateSectionMap];
}

- (void)updateSectionMap
{
    
    // Reset the mapping
    
    for (TASectionInfo *si in _allSections) {
        si.sectionIndexInFetchedResults = NSNotFound;        
    }
    
    // Create a mapping between the full section index and the section indexes returned by NSFetchResultsRequest (which
    // doesn't include any empty sections)
    
    if ([_allSections count] > 0) {
        
        NSLog(@"Updating section map");
        
        int sectionIdx = 0;
        
        for (id <NSFetchedResultsSectionInfo> sectionInfo in [self fetchedSections]) {
            
            NSString *nameFromFetchResults = sectionInfo.name;
            
            // Find the corresponding section
            // NSFetchedResultsController only returns us the "name" as supplied by the "sectionNameKeyPath". This name
            // is normally use to both group and order the sections; it must be unique for each section. We can therefore
            // use this to locate the actual section entity. The order of the section array can be totally different to that
            // returned by NSFetchedResultsController :)
            
            BOOL found = NO;
            for (int idx = 0; idx < _allSections.count; idx++)
            {
                TASectionInfo *si = [_allSections objectAtIndex:idx];
                NSString *propertyNameForSectionGrouping = [si.theManagedObject valueForKey:_propertyNameForSectionGrouping];
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

- (NSArray *)fetchedSections
{
    return [super sections];
}

- (id <NSFetchedResultsSectionInfo>)sectionInfoFromUITableViewControllerSectionIndex:(NSUInteger)section
{
    TASectionInfo *si = (TASectionInfo *)[_allSections objectAtIndex:section];    
    NSUInteger sectionIndex = si.sectionIndexInFetchedResults;
    if (sectionIndex == NSNotFound) // Empty section
        return nil;
    
    return [[self fetchedSections] objectAtIndex:sectionIndex];
}

- (NSIndexPath *)convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:(NSIndexPath *)indexPath usingMapping:(NSArray *)mapping
{    
    TASectionInfo *si = (TASectionInfo *)[mapping objectAtIndex:indexPath.section];    
    NSUInteger sectionIndex = si.sectionIndexInFetchedResults;
    if (sectionIndex == NSNotFound) // Empty section
        return nil;
    
    return [NSIndexPath indexPathForRow:indexPath.row inSection:sectionIndex];
}

- (NSIndexPath *)convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:(NSIndexPath *)indexPath
{
    return [self convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:indexPath usingMapping:_allSections];
}

- (NSIndexPath *)convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:(NSIndexPath *)indexPath usingMapping:(NSArray *)mapping
{    
    // Map the NSFetchedResults section index to the real section index
    
    int idx = 0;
    for (TASectionInfo *si in mapping) {
        NSUInteger sectionIndexInFetchedResults = si.sectionIndexInFetchedResults;
        if (sectionIndexInFetchedResults == indexPath.section) 
        {
            return [NSIndexPath indexPathForRow:indexPath.row inSection:idx];
        }
        idx++;
    }
    
    // There really should be one, other wise we have a big problem
    
    [NSException raise:@"No key found for NSIndexPath supplied by NSFetchedResultsController"
                format:@"No key found for NSIndexPath supplied by NSFetchedResultsController when searching for [%d, %d]", indexPath.section, indexPath.row
     ];
    
    return NULL; // Stop compiler warning
}

- (NSIndexPath *)convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:(NSIndexPath *)indexPath
{    
    return [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:indexPath usingMapping:_allSections];
}

- (id)objectAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger section = indexPath.section;
    NSUInteger row = indexPath.row;
    indexPath = [self convertUITableViewControllerIndexPathToNSFetchedResultsControllerIndexPath:indexPath];
    section = indexPath.section;
    row = indexPath.row;
    if (!indexPath) // Empty section
        return nil;
    
    return [super objectAtIndexPath:indexPath];
}

#pragma mark - Delegate Interception

- (void)setDelegate:(id)newDelegate
{
    // The Delegate Interceptor will automatically forward on calls that we don't intercept...
    
    [super setDelegate:nil];
    [_delegateInterceptor setReceiver:newDelegate];
    [super setDelegate:(id)_delegateInterceptor];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    // This will be called if a row has been moved to a new section or if the last row has been deleted from a section
    //
    // This will cause the indexPath passed to didChangeObject to become out of sync. If we update the mapping now then
    // the deleted section will no longer be mapped and didChangeObject: won't be able to find the correspinding section
    // in the table (traditionally it would have been delete from the table view at this point.
    // If we delay the remapping then we won't have a mapping for the the newly created section.
    //
    // We need to hold onto the old mapping (with the deleted section), remap, then use the appropriate table!
    
    NSLog(@"Section changes detected. Storing copy of old mapping and creating a new map");
    
    NSMutableArray *prevMapping = [NSMutableArray arrayWithCapacity:[_allSections count]];
    for (TASectionInfo *si in _allSections) {
        TASectionInfo *newInfo = [[TASectionInfo alloc] initWithManagedObject:nil];
        newInfo.sectionIndexInFetchedResults = si.sectionIndexInFetchedResults;
        [prevMapping addObject:newInfo];
    }
    
    self.previousMapping = prevMapping;
    [self updateSectionMap];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if ([(NSObject *)_delegateInterceptor.receiver respondsToSelector:@selector(controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:)]) {
        
        NSLog(@"TAFetchedResultsController has intercepted a delegate call to didChangeObject with indexPath [%d, %d] and newIndexPath [%d, %d].", indexPath.section, indexPath.row, newIndexPath.section, newIndexPath.row);
        
        // Use the previous mapping if there have been section changes
        
        NSArray *prevMapping = self.previousMapping;
        if (!prevMapping)
            prevMapping = _allSections;
        
        // Convert the NSFetchedResultsController based index path to that used by the UITableViewController
        
        NSIndexPath *convertedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        NSIndexPath *convertedNewIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        
        if (type != NSFetchedResultsChangeInsert) {
            // The indexPath must exists - convert it...
            convertedIndexPath = [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:indexPath usingMapping:prevMapping];
            NSLog(@"Converted indexPath from [%d, %d] to [%d, %d]", indexPath.section, indexPath.row, convertedIndexPath.section, convertedIndexPath.row);
        }
        
        if (type == NSFetchedResultsChangeMove || type == NSFetchedResultsChangeInsert) {
            // newIndexPath must exists - convert it...
            convertedNewIndexPath = [self convertNSFetchedResultsSectionIndexToUITableViewControllerSectionIndex:newIndexPath usingMapping:_allSections];
            NSLog(@"Converted newIndexPath from [%d, %d] to [%d, %d]", newIndexPath.section, newIndexPath.row, convertedNewIndexPath.section, convertedNewIndexPath.row);
        }
        
        // Pass this onto the user
        
        [_delegateInterceptor.receiver controller:controller
                                  didChangeObject:anObject
                                      atIndexPath:convertedIndexPath
                                    forChangeType:type
                                     newIndexPath:convertedNewIndexPath
         ];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"controllerDidChangeContent called - clearing previous mapping");
    self.previousMapping = nil;
    
    // Call the receiver's delegate
    
    if ([(NSObject *)_delegateInterceptor.receiver respondsToSelector:@selector(controllerDidChangeContent:)]) {
        [_delegateInterceptor.receiver controllerDidChangeContent:controller];
    }
}


@end
