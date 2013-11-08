TAFetchedResultsController
==========================

TAFetchedResultsController is a "subclass" of NSFetchedResultsController that allows for empty sections.

TAFetchedResultsController requires ARC and has been developed under iOS 5 - it has not been tested on iOS 4.

## NSFetchedResultsController's limitations

NSFetchedResultsController is a fantastic class, it allows you to map a core data entity to a UITableView, and keeps them in sync with each other through the use of delegate calls.

However, NSFetchedResultsController's support for sections is limited. While it is possible to divide the fetch results into sections, there are some severe limitations:

* You can't have empty sections.
* The ordering of the sections is based on the name that you wish to display in the section header. It's hard to separate the two without resorting to some very nasty techniques.
* There's no easy way to recover the section object (assuming that the keypath for section grouping points to another entity) other than searching for it by name.

## TAFetchedResultsController

TAFetchedResultsController is a "subclass" of NSFetchedResultsController that solves the above problems. It's *almost* a drop in replacement, but there are a few differences.

Subclass is in quotes because it doesn't truely subclass NSFetchedResultsController, but rather includes an instance of NSFetchedResultsController internally. This has beed done for technical reasons, but for all intents and purposes its interface is so clse to NSFetchedResultsController that dropping it into a project should be trivial.

If you don't know how to use NSFetchedResultsController then you should first read about that first in Apple's documentation. This document will assume that you understand how to use it.

## Core Data Model Requirements

Whereas NSFetchedResultsController manages one Entity (the items), TAFetchedResultsController manages two: the items and the sections. It is therefore necessary to have an Entity to manage the sections as well as the one for the items. The Sections entity will have a one-to-many relationship to the items that it contains. You'll also need a relationship back again.

The delete rule for the items relationship should be set to *cascade*. This will ensure that when you delete a section the items will be deleted first and thus removed from the table. This author hasn't tried using any other delete rule and has no idea what the consequences would be (if any).

Section Entities need to have a unique and unchanging string key be which they can be identified. This property should be used when suppying a key path name to group the items into sections.

## Initialisation

The initialisation of a TAFetchedResultsController is very similar to that of an NSFetchResultsController, however you must create a second fetch request for the sections. In general, you should:

* Create a fetch request for the items.
* Ensure that the items are grouped first by section using the keypath to access an unique identifier on the section Entity. (NSFetchResultsController also require this, although you're force to group using the property that will also be used for the section name).
* Create a fetch request for the sections.
* Sort them any way you please (this will be the order they appear in the table).
* Create the TAFetchedResultsController passing in these two fetch requests and the key path from the Item's entity to the property in the Section's entity that you're using to uniquely identify it.

 Typically then, it'll look something like this:

      - (TAFetchedResultsController *)taFetchedResultsController
      {
          if (_taFetchedResultsController != nil) {
              return _taFetchedResultsController;
          }
          
          // Prepare a fetch request for the items
          
          NSFetchRequest *itemFetchRequest = [[NSFetchRequest alloc] init];
          NSEntityDescription *entity = [NSEntityDescription entityForName:@"Item" inManagedObjectContext:self.managedObjectContext];
          [itemFetchRequest setEntity:entity];
          
          // Set the batch size to a suitable number.
          
          [itemFetchRequest setFetchBatchSize:20];
          
          // Edit the sort key as appropriate.
          //
          // As with NSFetchedResultsController, we first have to group into sections. For the demo we assume that
          // sections names are unique...
          //
          // We then order the items alphabetically by name within each section
          
          NSSortDescriptor *groupingDescriptor = [[NSSortDescriptor alloc] initWithKey:@"section.name" ascending:YES];
          NSSortDescriptor *nameDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
          NSArray *sortDescriptors = [NSArray arrayWithObjects:groupingDescriptor, nameDescriptor, nil];
          
          [itemFetchRequest setSortDescriptors:sortDescriptors];
          
          // Prepare a fetch request for the Section headers 
          
          NSEntityDescription *sectionEntityDescription = [NSEntityDescription entityForName:@"Section" inManagedObjectContext:self.managedObjectContext];
          NSFetchRequest *sectionFetchRequest = [[NSFetchRequest alloc] init];
          [sectionFetchRequest setEntity:sectionEntityDescription];
          
          // For this demo, order by timestamp
          //
          // Note that unlike for NSFetchedResultsController, TAFetchedResultsController allows use to arbitrarily order the sections.
          
          NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:YES];
          [sectionFetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
          
          // Create the TAFetchedResultsController
          
          TAFetchedResultsController *taFetchedResultsController = [[TAFetchedResultsController alloc] initWithItemFetchRequest:itemFetchRequest
                                                                                                            sectionFetchRequest:sectionFetchRequest
                                                                                                           managedObjectContext:self.managedObjectContext
                                                                                                         sectionGroupingKeyPath:@"section.name"
                                                                                                                      cacheName:nil];
          
          // We want to respond to model changes
          
          taFetchedResultsController.delegate = self;
          
          self.taFetchedResultsController = taFetchedResultsController;
          
         NSError *error = nil;
         if (![self.taFetchedResultsController performFetch:&error]) {
              // Replace this implementation with code to handle the error appropriately.
              // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
             abort();
         }
          
          return _taFetchedResultsController;
      }    

## Using TAFetchedResultsSectionInfo

TAFetchedResultsSectionInfo is used is much the same way as NSFetchedResultsSectionInfo. You should respond to the same callbacks to update your table, and you should ask it for information about your sections and cells in your table's datasource methods.

The big gotcha is that you should **always** use the *allSections* method to get a list of the sections. The *sections* method will return the list from the underlying base class, and will therefore be incomplete (missing as it will the empty sections).

For example:

    - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
    {
        // This is handled as for NSFetchedResultsController, but we must be careful to access 'allSections' and not 'sections'.
    
        id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    }

## TAFetchedResultsSectionInfo

TAFetchedResultsSectionInfo is a subclass of NSFetchedResultsSectionInfo. An array of TAFetchedResultsSectionInfos are passed back to you when you call allSections on the controller. The key difference is that you have access to the NSManagedObject for the section.

    @property (nonatomic, readonly) NSManagedObject *theManagedObject;

Having the object is a very useful thing to have! Now you can easily access all the fields in order to return a sensible section name (unlike for NSFetchedResultsController!)

## Responding to section changes

TAFetchedResultsController listens to context changes that will affect your sections (such as the insertion and deletion of sections) and calls your delegate to inform your to update your table.

Notice that unlike NSFetchedResultsController you will also be informed if a section is updated. This may be useful if the section's title can be changed at any time.

While this is very useful feature, you should be aware that Core Data may report a section change when one of its items is modified in **any** way. It would therefore be unwise to simply reload the section title for any change request that you received, or else there will be unnecessary flickering of the section header whenever one of it's rows changes.

The demonstration project shows you one way to handle this issue by testing to see if the section's title has changed before you update the header. Unfortunately this requires some legwork since UITableView doesn't provide access to the headers so they need to be tracked manually.

Another option is to remove the reverse relationship between the item Entity and the Section Entity in the core data model. In this way Core Data won't report any modifications to the items as changes to the section. Be aware though that Apple recommend always having the reverse relationship unless there's a very good reason not do do so.

## Delegate methods

The deleage methods are virtually the same as for NSFetchedResultsController; you see see that for the details.

#### controllerWillChangeContent:

Notifies the receiver that the fetched results controller is about to start processing of one or more changes due to an add, remove, move, or update.

You should use that deletate to issus a beginUpdates to  your table view.

#### controller:didChangeObject:atIndexPath:forChangeType:newIndexPath:

Notifies the receiver that a fetched object has been changed due to an add, remove, move, or update. You should update the associated table row.

#### controller:didChangeSection:atIndex:forChangeType:

Notifies the receiver of the addition or removal of a section.

Unlike NSFetchedResultsController, you will also been informated of any updates to the section, and you should update your section header **if** it's been changed. See *Responding to section changes* above for more details.

#### controllerDidChangeContent:

Notifies the receiver that the fetched results controller has completed processing of one or more changes due to an add, remove, move, or update.

You should use this to end the table updates.


How it works
============

TAFetchedResultsController still gives NSFetchedResultsController all the hard work to do. This is a good thing because it's a complex class and I'd rather get Apple's engineers to maintain it :)

The section indexes returned by NSFetchedResultsController only exist for sections which contain items. For example, imagine that we have an entity called section which contains items. A hierarchy might look like this (the numbers are the indexes of an ordered fetch request on the sections):

    Section A (0)
       - Item x
       - Item y
    Section B (1)
    Section C (2)
       - Item z

NSFetchedResultsController would have returned as the following sections:

    Section A (0)
    Section C (1)
    
Section B would not have been returned since it contained no rows. At this point we have a problem - the indexes in the list of all the sections no longer match the indexes of the sections returned by NSFetchedResultsController.

TAFetchedResultsController solves this problem by maintaining a mapping between the real indexes and those returned by NSFetchedResultsController. Furthermore, TAFetchedResultsController intercepts the delegate calls from NSFetchedResultsController and converts the NSIndexPaths to make all this transparent.


Known Limitations
=================

## Section moves are not yet tracked

TAFetchedResultsController will reponds to changes in your Section objects and call you back to insert, delete or update sections as required.

However, changes to section order are not yet handled, and the behaviour is currently undefined should you do this.
