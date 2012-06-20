//
//  DemoViewController.m
//  TAFetchedResultsControllerDemo
//
//  Created by Timothy Armes on 20/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DemoViewController.h"

#import "Section.h"
#import "Item.h"

@interface DemoViewController ()

@property (weak, nonatomic) Section *mostRecentlyCreatedSection;
@property (strong, nonatomic) TAFetchedResultsController *taFetchedResultsController;
@property (nonatomic) BOOL inManualReorder;

- (void)configureView;

@end

@implementation DemoViewController

@synthesize tableView = _tableView;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize taFetchedResultsController = _taFetchedResultsController;
@synthesize mostRecentlyCreatedSection = _mostRecentlyCreatedSection;
@synthesize inManualReorder = _inManualReorder;

#pragma mark - Managing the detail item

- (void)configureView
{
    // This shgould happen automatically once TAFetchedResultsController is finished
    [self.taFetchedResultsController updateSections];
    
    // Set up the table
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // Do any additional setup after loading the view, typically from a nib.
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    
    [self configureView];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    self.taFetchedResultsController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = NSLocalizedString(@"Detail", @"Detail");
    }
    return self;
}

-(void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

#pragma mark - Table View

- (Item *)itemAtIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.taFetchedResultsController objectAtIndexPath:indexPath];
    return (Item *)object;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // This is handled as for NSFetchedResultsController, but we must be careful to access 'allSections' and not 'sections'.
    
    NSUInteger numSections = [[self.taFetchedResultsController allSections] count];    
    return numSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // This is handled as for NSFetchedResultsController, but we must be careful to access 'allSections' and not 'sections'.
    
    id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

// Customize the appearance of table view cells.

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ItemCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.showsReorderControl = YES;
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (editingStyle) {
        case UITableViewCellEditingStyleDelete:
        {
            [self.managedObjectContext deleteObject:[self.taFetchedResultsController objectAtIndexPath:indexPath]];
            
            NSError *error = nil;
            if (![self.managedObjectContext save:&error]) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            }
        }
            break;
            
        default:   
            break;
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // In this demo we allow rows to be moved, but only between sections. Order within a section is always alphabetical....
    return YES;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    // In this demo we allow rows to be moved, but only between sections. Order within a section is always alphabetical....
        
    // If the sections are the same, don't allow the move since it's already in order
    
    if (sourceIndexPath.section == proposedDestinationIndexPath.section)
        return sourceIndexPath;
    
    // If they're not the same, place it in the right (alphabetical) position....
    
    Item *itemToMove = [self itemAtIndexPath:sourceIndexPath];
    
    id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:proposedDestinationIndexPath.section];
    NSArray *items = [sectionInfo objects];
    NSUInteger idx = 0;
    for (Item *itemInSection in items) {
        NSComparisonResult res = [itemInSection.name compare:itemToMove.name options:NSCaseInsensitiveSearch];
        if (res == NSOrderedDescending)
            break;
        
        idx++;
    }
    
    return [NSIndexPath indexPathForRow:idx inSection:proposedDestinationIndexPath.section];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    self.inManualReorder = YES;
    
    Item *item = [self itemAtIndexPath:fromIndexPath];
    id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:toIndexPath.section];
    Section *newSection = (Section *)sectionInfo.theManagedObject;

    // Assign the item to the new section
    
    if (item.section != newSection)
        item.section = newSection;
    
    // Save the managed context

    NSError *error = nil;
    if (![self.managedObjectContext save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    self.inManualReorder = NO;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    id <TAFetchedResultsSectionInfo> sectionInfo = [[self.taFetchedResultsController allSections] objectAtIndex:section];
    return sectionInfo.name;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Item *item = [self itemAtIndexPath:indexPath];
    cell.textLabel.text = item.name;
}   

#pragma mark - Fetched results controller

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
    
    // For this demo, we order by timestamp
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

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.inManualReorder)
        [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    // This isn't yet handled by TAFetchedResultsController
    //
    // Until then, the table should be reloaded manually whenever the sections change...
    
    /*
     switch(type) {
     case NSFetchedResultsChangeInsert:
     break;
     
     case NSFetchedResultsChangeDelete:
     break;
     }
     */
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    // This is handled as for NSFetchedResultsController
    
    UITableView *tableView = self.tableView;
    
    if (!self.inManualReorder)
    {
        switch(type) {
            case NSFetchedResultsChangeInsert:
                NSLog(@"TAFetchResultsController requesting INSERT at [%d, %d]", newIndexPath.section, newIndexPath.row);
                [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
                break;
                
            case NSFetchedResultsChangeDelete:
                NSLog(@"TAFetchResultsController requesting DELETE to [%d, %d]", indexPath.section, indexPath.row);
                [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
                break;
                
            case NSFetchedResultsChangeUpdate:
                NSLog(@"TAFetchResultsController requesting UPDATE to [%d, %d]", indexPath.section, indexPath.row);
                [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
                break;
                
            case NSFetchedResultsChangeMove:
                NSLog(@"TAFetchResultsController requesting MOVE from [%d, %d] to [%d, %d]", indexPath.section, indexPath.row, newIndexPath.section, newIndexPath.row);
                NSLog(@"Updating table MOVE request");
                [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
                [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.inManualReorder)
        [self.tableView endUpdates];
}

#pragma mark - Button handling

- (IBAction)addNewSection:(id)sender {
    
    
    Section *newSection = [NSEntityDescription insertNewObjectForEntityForName:@"Section" inManagedObjectContext:self.managedObjectContext];
    
    newSection.name = [NSString stringWithFormat:@"Section %d", [[self.taFetchedResultsController allSections] count] + 1];
    newSection.timeStamp = [NSDate date];
    
    // Save the context.
    NSError *error = nil;
    if (![self.managedObjectContext save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    self.mostRecentlyCreatedSection = newSection;
    
    [self.taFetchedResultsController updateSections]; // This should be automatic in the final release
    
    [self.tableView reloadData];
}

- (IBAction)addNewItem:(id)sender {
    
    // Make sure there's at least one section.
    
    if ([self.taFetchedResultsController.allSections count] == 0)
        [self addNewSection:nil];
    
    // If we havn't added a section in this session, just add the item to the first one for the purposes of this demo
    
    if (!self.mostRecentlyCreatedSection)
    {
        id <TAFetchedResultsSectionInfo> si = (id <TAFetchedResultsSectionInfo>)[self.taFetchedResultsController.allSections objectAtIndex:0];
        self.mostRecentlyCreatedSection = (Section *)si.theManagedObject;
    }
    
    // Create the Item
    
    NSManagedObjectContext *context = self.managedObjectContext;
    Item *newItem = [NSEntityDescription insertNewObjectForEntityForName:@"Item" inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    
    newItem.name = [NSString stringWithFormat:@"New Item %d", [self.taFetchedResultsController.fetchedObjects count] + 1];
    newItem.section = self.mostRecentlyCreatedSection;
    
    // Save the context
    
    NSError *error = nil;
    if (![context save:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    // Note: TAFetchedResultsController will call back to update the UITableView
}
@end
