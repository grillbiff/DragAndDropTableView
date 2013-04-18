//
//  DragAndDropTableView.h
//  DragAndDropTableView
//
//  Created by Erik Johansson on 4/1/13.
//  Copyright (c) 2013 Erik Johansson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import </usr/include/objc/objc-class.h>

@class ProxyDataSource;
@class ProxyDelegate;
@class DragAndDropTableView;

@protocol DragAndDropTableViewDataSource <NSObject>
@optional
-(BOOL)canCreateNewSection:(NSInteger)section;
@end

@protocol DragAndDropTableViewDelegate <NSObject>
@optional
-(void)tableView:(DragAndDropTableView *)tableView willBeginDraggingCellAtIndexPath:(NSIndexPath *)indexPath placeholderImageView:(UIImageView *)placeHolderImageView;
-(void)tableView:(DragAndDropTableView *)tableView didEndDraggingCellWithPlaceHolderView:(UIImageView *)placeholderImageView;
@end

@interface DragAndDropTableView : UITableView<UITableViewDataSource>
{
    UIGestureRecognizer *_dndLongPressGestureRecognizer;
    
    NSIndexPath *_movingIndexPath;
    NSIndexPath *_originIndexPath;
    UIImageView *_cellSnapShotImageView;
    UIImageView *_tableViewSnapShotImageView;
    Method _originalSwizzledMethod;
    
    CGPoint _touchOffset;
    BOOL _lastIndexPathValid;
    NSIndexPath *_tempNewSectionIndexPath;
    
    ProxyDataSource *_proxyDataSource;
    ProxyDelegate *_proxyDelegate;
    
    CGFloat _autoscrollDistance;
    NSTimer *_autoscrollTimer;
    CGPoint _latestTouchPoint;
}

@end
