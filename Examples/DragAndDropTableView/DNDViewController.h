//
//  DNDViewController.h
//  DragAndDropTableView
//
//  Created by Erik Johansson on 4/1/13.
//  Copyright (c) 2013 Erik Johansson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DragAndDropTableView.h"

@interface DNDViewController : UIViewController<UITableViewDelegate,UITableViewDataSource,DragAndDropTableViewDataSource,DragAndDropTableViewDelegate>
{
    NSMutableArray *_datasource;
    DragAndDropTableView *_tableView;
}
@end
