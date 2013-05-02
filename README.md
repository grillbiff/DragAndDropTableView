DragAndDropTableView
=
DragAndDropTableView is a UITableView which supports drag and drop reordering of table cells.

## Installation
### Manual
- Download sources and add the DragAndDropFolder to your project
- Make sure the QuartzCore framework is added to your project
- Create a DragAndDropTable and start dragging and dropping

### CocoaPods
- Yes, it's on CocoaPods :)

## Usage
DragAndDropTableView operates the same way your standard UITableView does except for a few added protocols.

``` objective-c
@protocol DragAndDropTableViewDataSource <NSObject>
@optional
-(BOOL)canCreateNewSection:(NSInteger)section;
@end
```
``` objective-c
@protocol DragAndDropTableViewDelegate <NSObject>
@optional
-(void)tableView:(DragAndDropTableView *)tableView willBeginDraggingCellAtIndexPath:(NSIndexPath *)indexPath placeholderImageView:(UIImageView *)placeHolderImageView;
-(void)tableView:(DragAndDropTableView *)tableView didEndDraggingCellToIndexPath:(NSIndexPath *)indexPath placeHolderView:(UIImageView *)placeholderImageView;
-(CGFloat)tableView:(DragAndDropTableView *)tableView heightForEmptySection:(int)section;
@end
```

As you can see all methods are optional. If you choose to implement the protocols the UITableViewDataSource used by your table should implement the DragAndDropTableViewDataSource protocol and your UITableViewDelegate should implement the DragAndDropTableViewDelegate protocol.

See the example project for further help.

## Licence
DragAndDropTableView is available under the MIT license. See the LICENSE file for more info.