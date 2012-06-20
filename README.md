TAFetchedResultsController
==========================

TAFetchedResultsController is a subclass of NSFetchedResultsController that allows for empty sections.

**IMPORTANT NOTE:** This project's advanceing very well, but it's not quote yet ready for use. See the limitations described in this document. Please feel free to help the advancement!

## NSFetchedResultsController limitations

NSFetchedResultsController is a fantastic class, it allows you to map a core data entity to a UITablView, and keeps them in sync with each other through the use of delegate calls.

However, NSFetchedResultsController's support for sections is limited. While it is possible to divide the fetch results into sections, there are some severe limitations:

* You can't have empty sections.
* The ordering of the sections is based on the name that you wish to display in the section header. It's hard to separate the two without resorting to some very nasty techniques.
* There's no easy way to recover the section object (assuming that the keypath for section grouping points to another entity) other than searching for it by title.

## TAFetchedResultsController

TAFetchedResultsController is a subclass of NSFetchedResultsController that solves the above problems. It's *almost* a drop in replacement, but there are a few differences.

If you don't know how to use NSFetchedResultsController then read about that first in Apple's documentation. This readme file will assume that you understand how to use it.

Whereas NSFetchedResultsController manages one Entity (the items), TAFetchedResultsController manages two: the items and the sections. It is therefore necessary to have an Entity to manage the sections as well as the one for the items. The Sections entity will have a one-to-many relationship to the items that it contains. You'll also need a relationship back again.

### Initialisation

The initialisation of a TAFetchedResultsController is very similar to that of an NSFetchResultsController, however we create a second fetch request for the sections. In general, you should:

* Create a fetch request for the items
* Ensure that the items are grouped first by section using the keypath to access an unique identifier on the section Entity. (NSFetchResultsController also require this, although you're force to group using the property that will also be used for the section name).
* Create a fetch request for the sections
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

TAFetchedResultsSectionInfo is used is much the same way as NSFetchedResultsSectionInfo. You should respond to the same callback to update your table, and you should ask it for information about your sections and cells in your table's datasource methods.

The big gotcha is that you should **always** use the *allSections* method to get a list of the sections. The *sections* method will return the list from the underlying base class, and will therefore be incomplete (missing as it will the empty sections).

For example:

    - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
    {
        // This is handled as for NSFetchedResultsController, but we must be careful to access 'allSections' and not 'sections'.
    
        id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:section];
        return [sectionInfo numberOfObjects];
    }

## TAFetchedResultsControllerDelegate
 
TAFetchedResultsControllerDelegate is subclass of NSFetchedResultsControllerDelegate that adds one extra callback:
 
    - (NSString *)controller:(NSFetchedResultsController *)controller sectionNameForObject:(NSManagedObject *)sectionObject;

Implement this to return the section's name for the UITableView. Note that you're passed the underlying object - how handy :)

## TAFetchedResultsSectionInfo

TAFetchedResultsSectionInfo is a subclass of NSFetchedResultsSectionInfo. An array of TAFetchedResultsSectionInfos are passed back to you when you call allSection on the controller. The big difference is that you have access to the NSManagedObject for the section

    @property (nonatomic, readonly) NSManagedObject *theManagedObject;



How it works
============

TAFetchedResultsController still gives NSFetchedResultsController all the hard work to do. This is a good thing because it's a complex class and I'd rather get Apple's engineers to maintain it :)

The section indexes returned by NSFetchedResultsController only exist for sections which contain items. For example, image that we have an entity called section which contains items. A hierarchy might look like this:

    Section A (0)
       - Item x
       - Item y
    Section B (1)
    Section C (2)
       - Item z

The numbers are the indexes of an ordered fetch request on the sections.

NSFetchedResultsController would have returned as the following sections:

    Section A (0)
    Section C (1)
    
Section B would not have been returned since it contained no rows. At this point we have a problem - the index of the list of all the sections no longer match the indexes of the sections returned by NSFetchedResultsController.

TAFetchedResultsController solves this problem by maintaining a mapping between the real indexes and those returned by NSFetchedResultsController. Furthermore, TAFetchedResultsController intercepts the delegate calls from NSFetchedResultsController and converts the NSIndexPaths to make all this transparent.


Known Limitations
=================

## Changes to the list of sections are not yet detected

NSFetchedResultsController provides a callback for when new sections are created and deleted:

    - (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type

Under NSFetchedResultsController a section would suddenly appear when a row was assigned to it. It would disappear when the last row was removed.

TAFetchedResultsController is different in that the list of sections is provided by a model entity for which you provide a fetch request. However, it doesn't *yet* listen to changes within the Section Entity. This means that you won't currently receive any calls to the above callback.

You'll need to handle this yourself until this has been done…

## Using [self.taFetchedResultsController sections] will get you in trouble

When converting existing code to use TAFetchedResultsController you must remember to use the *allSections* accessor on the controller, and not the *sections* accessor.

It would have been lovely to override this property to return all the sections, thereby making this class even closer to a drop in replacement. However, it seems that the NSFetchedResultsController implementation internally calls self.sections. When it does this it's important that it recovers it's own internal list of sections and not our replacement list (NSFetchedResultsController must no nothing about what we're doing for this to work).

If there's a solution to this problem, or a way to ensure that the user doesn't call *sections* by accident, I'd love to know about it….

