//
//  TAFetchedResultsController.h
//  ShoppingList
//
//  Created by Timothy Armes on 13/06/2012.
//  Copyright (c) 2012 Timothy Armes. All rights reserved.
//
//  This subclass extends NSFetchedResultsController to allow for empty sections to be handled.
//  It requires a one-to-many (section-to-items) core data model.

#import <CoreData/CoreData.h>

// Extend the NSFetchedResultsSectionInfo protocol to return the managed object for the section

@protocol TAFetchedResultsSectionInfo <NSFetchedResultsSectionInfo>

@property (nonatomic, readonly) NSManagedObject *theManagedObject;

@end

// Subclass NSFetchedResultsController

@interface TAFetchedResultsController : NSFetchedResultsController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) NSArray *allSections;
@property (weak, nonatomic) id <NSFetchedResultsControllerDelegate> delegate;
@property BOOL disabled;

/* Initializes an instance of TAFetchedResultsController
 
 itemFetchRequest - the fetch request used to get the objects. It's expected that the sort descriptor used in the request groups the objects into sections.
 sectionFetchRequest - the fetch request used to get the sections.
 context - the context that will hold the fetched objects
 sectionGroupingKeyPath - keypath on resulting objects that uniquely identifies the section. The items should have be sorted on this property.
 propertyNameForSectionName - name of the section entity's property that will be user for the name 
 cacheName - Section info is cached persistently to a private file under this name. Cached sections are checked to see if the time stamp matches the store, but not if you have illegally mutated the readonly fetch request, predicate, or sort descriptor.
 
 */

- (id)initWithItemFetchRequest:(NSFetchRequest *)itemFetchRequest
           sectionFetchRequest:(NSFetchRequest *)sectionFetchRequest
          managedObjectContext:(NSManagedObjectContext *)context
        sectionGroupingKeyPath:(NSString *)sectionGroupingKeyPath
                     cacheName:(NSString *)name;

- (void)updateSections;

// Use this instead of indexPathForObject:

- (NSIndexPath *)taIndexPathForObject:(id)object;

@end
