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
#import <UIKit/UIKit.h>

// Extend the NSFetchedResultsSectionInfo protocol to return the managed object for the section

@protocol TAFetchedResultsSectionInfo <NSFetchedResultsSectionInfo>

@property (nonatomic, readonly) NSManagedObject *theManagedObject;

@end

// TAFetchedResultsControllerDelegate protocol
//
// This is virtually identical to the NSFetchedResultsController protocol except that the controller involved
// is a TAFetchedResultsControllerDelegate.
//

@class TAFetchedResultsController;

@protocol TAFetchedResultsControllerDelegate <NSObject>

- (void)controller:(TAFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath;

- (void)controller:(TAFetchedResultsController *)controller
  didChangeSection:(id <TAFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type;

- (void)controllerDidChangeContent:(TAFetchedResultsController *)controller;
- (void)controllerWillChangeContent:(TAFetchedResultsController *)controller;


@end

// "Subclass" of NSFetchedResultsController

@interface TAFetchedResultsController : NSObject <NSFetchedResultsControllerDelegate>

@property (nonatomic, readonly) NSFetchRequest *itemFetchRequest;
@property (nonatomic, readonly) NSFetchRequest *sectionFetchRequest;
@property (nonatomic, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly) NSString *cacheName;
@property (nonatomic, readonly) NSArray *fetchedObjects;
@property (nonatomic, readonly) NSArray *sections;
@property (nonatomic, readonly) NSArray *sectionIndexTitles;
@property (nonatomic, strong)   NSString *sectionIndexTitleKeyPath;

@property (weak, nonatomic) id <TAFetchedResultsControllerDelegate> delegate;
@property (atomic) BOOL disabled;

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

- (NSInteger)sectionForSectionIndexTitle:(NSString *)title
                                 atIndex:(NSInteger)sectionIndex;

/* Force the controlled to update the sections. This isn't expected to be useful since it handles this automatically */

- (void)updateSections;

/* NSFetchedResultsController functions */

- (id)objectAtIndexPath:(NSIndexPath *)indexPath;
- (NSIndexPath *)indexPathForObject:(id)object;
- (BOOL)performFetch:(NSError **)error;

+ (void)deleteCacheWithName:(NSString *)name;

@end
