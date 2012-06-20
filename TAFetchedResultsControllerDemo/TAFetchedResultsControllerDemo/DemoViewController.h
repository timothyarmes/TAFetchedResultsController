//
//  DemoViewController.h
//  TAFetchedResultsControllerDemo
//
//  Created by Timothy Armes on 20/06/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TAFetchedResultsController.h"
#import "Section.h"

@interface DemoViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, TAFetchedResultsControllerDelegate> 

@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

- (IBAction)addNewSection:(id)sender;
- (IBAction)addNewItem:(id)sender;

@end
