//
//  DragAndDropTableView.m
//  DragAndDropTableView
//
//  Created by Erik Johansson on 4/1/13.
//  Copyright (c) 2013 Erik Johansson. All rights reserved.
//

#import "DragAndDropTableView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Snapshot.h"

const static CGFloat kAutoScrollingThreshold = 60;

@interface Proxy : NSObject
{
    __weak NSObject *_proxyObject;
}

@end

@interface ProxyDataSource : Proxy<UITableViewDataSource>

@property (nonatomic,weak) NSObject<UITableViewDataSource> *dataSource;
@property (nonatomic) NSIndexPath *movingIndexPath;

-(id)initWithDataSource:(id<UITableViewDataSource>)datasource;

@end

@interface ProxyDelegate : Proxy<UITableViewDelegate>
{
    __weak NSObject<UITableViewDelegate> *_delegate;
}


-(id)initWithDelegate:(id<UITableViewDelegate>)delegate;

@end




@implementation DragAndDropTableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setup];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        // Initialization code
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Initialization code
        [self setup];
    }
    return self;
}

-(void)setup
{
    // register gesture recognizer
    _dndLongPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressGestureRecognizerTap:)];
    [self addGestureRecognizer:_dndLongPressGestureRecognizer];
    
    _pendingInserts = [NSMutableArray new];
    _pendingDeletes = [NSMutableArray new];
}

#pragma mark Actions

-(void)beginUpdates
{
    // check which sections has placeholders before we start updating the datasource 
    [super beginUpdates];
}

-(void)endUpdates
{
    // handle pending inserts
    
    NSInteger sections = [_proxyDataSource.dataSource numberOfSectionsInTableView:self];
    NSMutableArray *indexPathsToDelete = [NSMutableArray new];
    for(NSIndexPath *indexPath in _pendingInserts)
    {
        // if we are inserting into a empty section which has a placeholder, remove the placeholder
        if(indexPath.section < sections && [_proxyDataSource.dataSource tableView:self numberOfRowsInSection:indexPath.section] == 1)
        {
            [indexPathsToDelete addObject:indexPath];
        }
    }
    
    if(indexPathsToDelete.count > 0)
        [super deleteRowsAtIndexPaths:indexPathsToDelete withRowAnimation:UITableViewRowAnimationNone];

    [_pendingInserts removeAllObjects];
    
    
    // handle pending deletes
    NSMutableArray *indexPathsToInsert = [NSMutableArray new];
    for(NSIndexPath *indexPath in _pendingDeletes)
    {
        // if we are deleting the last row in the section we need to insert the placeholder
        if(indexPath.section < sections && [_proxyDataSource.dataSource tableView:self numberOfRowsInSection:indexPath.section] == 0)
        {
            [indexPathsToInsert addObject:indexPath];
        }
    }
    
    if(indexPathsToInsert.count > 0)
        [super insertRowsAtIndexPaths:indexPathsToInsert withRowAnimation:UITableViewRowAnimationNone];
    
    [_pendingDeletes removeAllObjects];
    
    [super endUpdates];
}

-(void)insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if(!_isMoving)
        [_pendingInserts addObjectsFromArray:indexPaths];
    
    [super insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

-(void)deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if(!_isMoving)
        [_pendingDeletes addObjectsFromArray:indexPaths];
    
    [super deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}


-(void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    if(!_isMoving)
    {
        [_pendingInserts addObject:newIndexPath];
        [_pendingDeletes addObject:indexPath];
    }
    
    [super moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
}

-(void)onLongPressGestureRecognizerTap:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if(UIGestureRecognizerStateBegan ==  gestureRecognizer.state)
    {
        _latestTouchPoint = [gestureRecognizer locationInView:self];
        
        // get index path of position
        _movingIndexPath = _originIndexPath = [self indexPathForRowAtPoint:_latestTouchPoint];

        BOOL validMove = YES;
        // Check if we are allowed to move it
        if (![self.delegate respondsToSelector:@selector(tableView:canMoveRowAtIndexPath:)])
            validMove = NO;
        
        if (validMove && ![self.dataSource tableView:self canMoveRowAtIndexPath:_movingIndexPath])
            validMove = NO;
        
        // Check for a valid index path, otherwise cancel the touch
        if (validMove && (!_originIndexPath || [_originIndexPath section] == NSNotFound || [_originIndexPath row] == NSNotFound))
            validMove = NO;
        
        if(!validMove)
        {
            gestureRecognizer.enabled = !(gestureRecognizer.enabled = NO);
            return;
        }
        
        // Get the touched cell and reset it's selection state
        UITableViewCell *cell = [self cellForRowAtIndexPath:_movingIndexPath];
        
        // Compute the touch offset from the cell's center
        _touchOffset = CGPointMake([cell center].x - _latestTouchPoint.x, [cell center].y - _latestTouchPoint.y);
        
        // let the fake datasource know which indexpath is moving
        _proxyDataSource.movingIndexPath = _movingIndexPath;
        
        // create a snapshot of the cell we are about to move
        _cellSnapShotImageView = [[UIImageView alloc] initWithImage:[cell snapshotImage]];
        _cellSnapShotImageView.alpha = .6;
        [self addSubview:_cellSnapShotImageView];
        _cellSnapShotImageView.center = CGPointMake(_cellSnapShotImageView.center.x, _latestTouchPoint.y + _touchOffset.y);

        if([self.delegate respondsToSelector:@selector(tableView:willBeginDraggingCellAtIndexPath:placeholderImageView:)])
            [((NSObject<DragAndDropTableViewDelegate> *)self.delegate) tableView:self willBeginDraggingCellAtIndexPath:_movingIndexPath placeholderImageView:_cellSnapShotImageView];
        
        [self reloadRowsAtIndexPaths:[NSArray arrayWithObject:_movingIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        _isMoving = YES;
        
    }
    else if(UIGestureRecognizerStateChanged == gestureRecognizer.state)
    {
        _latestTouchPoint = [gestureRecognizer locationInView:self];

        // check if we've moved close enough to an edge to autoscroll, or far enough away to stop autoscrolling
        [self maybeAutoscrollForSnapshot:_cellSnapShotImageView];
        
        // Update the snap shot's position
        _cellSnapShotImageView.center = CGPointMake(_cellSnapShotImageView.center.x, _latestTouchPoint.y + _touchOffset.y);
        
        NSIndexPath *newIndexPath = [self indexPathForRowAtPoint:_latestTouchPoint];
        if(newIndexPath)
        {
            _lastIndexPathValid = YES;
            if(![newIndexPath isEqual:_movingIndexPath])
            {
                // ask the delegate to show a new location for the move
                if([self.delegate respondsToSelector:@selector(tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:)])
                    newIndexPath = [self.delegate tableView:self targetIndexPathForMoveFromRowAtIndexPath:_movingIndexPath toProposedIndexPath:newIndexPath];
                
                
                [self beginUpdates];
                [self moveRowAtIndexPath:_movingIndexPath toIndexPath:newIndexPath];
                // inform datasource
                if ([self.dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)])
                    [self.dataSource tableView:self moveRowAtIndexPath:_movingIndexPath toIndexPath:newIndexPath];
                [self endUpdates];
                
                [self bringSubviewToFront:_cellSnapShotImageView];
                
                _movingIndexPath = newIndexPath;
            }
            
            // remove the temp section if it exists and we are not proposing a move to it
            
            if(_tempNewSectionIndexPath && newIndexPath.section != _tempNewSectionIndexPath.section)
            {

                [self.dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:_tempNewSectionIndexPath];
                _tempNewSectionIndexPath = nil;
            }
                
        }
        else if(_lastIndexPathValid && !_tempNewSectionIndexPath)
        {
            // check if we are above or below the "valid" table and propose a new section if supported by the delegate
            NSInteger maxSection = 1;
            if([self.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)])
            {
                maxSection = [self.dataSource numberOfSectionsInTableView:self];
            }
            NSIndexPath *proposedIndexPath = nil;
            if(_latestTouchPoint.y > [self rectForFooterInSection:maxSection-1].origin.y) //CGRectGetMaxY([self rectForFooterInSection:maxSection-1]))
            {
                proposedIndexPath = [NSIndexPath indexPathForRow:0 inSection:maxSection];
            }
            else if (_latestTouchPoint.y < self.frame.origin.y)
            {
                proposedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
            }
            
            if(proposedIndexPath)
            {
                _lastIndexPathValid = NO;
                
                // check if we are allowed to create a new section
                // creating new sections "above" the table is not supported (yet).
                if(proposedIndexPath.section > 0 &&
                   [self.dataSource respondsToSelector:@selector(canCreateNewSection:)] &&
                   [self.dataSource performSelector:@selector(canCreateNewSection:) withObject:[NSNumber numberWithInteger:proposedIndexPath.section]])
                {
                    [self.dataSource tableView:self commitEditingStyle:UITableViewCellEditingStyleInsert forRowAtIndexPath:proposedIndexPath];

                    _tempNewSectionIndexPath = proposedIndexPath;
                    _lastIndexPathValid = YES;
                    
                    [self scrollToRowAtIndexPath:proposedIndexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                    
                    [self bringSubviewToFront:_cellSnapShotImageView];
                }
            }
        }
        
    }
    else if(UIGestureRecognizerStateEnded == gestureRecognizer.state || UIGestureRecognizerStateCancelled == gestureRecognizer.state)
    {
        if(_autoscrollTimer)
        {
            [_autoscrollTimer invalidate]; _autoscrollTimer = nil;
        }

        // since anything can happen with the table structure in the following delegate call we use the cell as reference rather than the indexpath to it
        UITableViewCell *cell = [self cellForRowAtIndexPath:_movingIndexPath];

        if([self.delegate respondsToSelector:@selector(tableView:didEndDraggingCellAtIndexPath:toIndexPath:placeHolderView:)])
            [((NSObject<DragAndDropTableViewDelegate> *)self.delegate) tableView:self didEndDraggingCellAtIndexPath:_originIndexPath toIndexPath:_movingIndexPath placeHolderView:_cellSnapShotImageView];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // keeping deprecated call for backwards compatibility
        if([self.delegate respondsToSelector:@selector(tableView:didEndDraggingCellToIndexPath:placeHolderView:)])
            [((NSObject<DragAndDropTableViewDelegate> *)self.delegate) tableView:self didEndDraggingCellToIndexPath:_movingIndexPath placeHolderView:_cellSnapShotImageView];
#pragma clang diagnostic pop
        
        // remove image
        BOOL respondsToAnimateDraggedCells = [self.dataSource respondsToSelector:@selector(tableViewShouldAnimateDraggedCells:)];
        if(!respondsToAnimateDraggedCells ||
           (respondsToAnimateDraggedCells && [((NSObject<DragAndDropTableViewDataSource> *)self.dataSource) tableViewShouldAnimateDraggedCells:self]))
        {
            [UIView animateWithDuration:.3 animations:^{
                NSIndexPath *ipx = [self indexPathForCell:cell];
                if(ipx)
                    _cellSnapShotImageView.frame = [self rectForRowAtIndexPath:ipx];
            } completion:^(BOOL finished) {
                [_cellSnapShotImageView removeFromSuperview]; _cellSnapShotImageView = nil;
                [self reloadData];
            }];
        }
        else
        {
            [_cellSnapShotImageView removeFromSuperview]; _cellSnapShotImageView = nil;
            [self reloadData];
        }
      
        _isMoving = NO;
        _proxyDataSource.movingIndexPath = nil;
        _tempNewSectionIndexPath = nil;
    }
}

#pragma mark -

#pragma mark Overrides

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_proxyDataSource tableView:tableView numberOfRowsInSection:section];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [_proxyDataSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

-(void)setDataSource:(id<UITableViewDataSource>)dataSource
{
    _proxyDataSource = dataSource ? [[ProxyDataSource alloc] initWithDataSource:dataSource] : nil;
    
    [super setDataSource:_proxyDataSource];
}

-(void)setDelegate:(id<UITableViewDelegate>)delegate
{
    _proxyDelegate = delegate ? [[ProxyDelegate alloc] initWithDelegate:delegate] : nil;
        
    [super setDelegate:_proxyDelegate];
} 

#pragma mark -

#pragma mark Autoscrolling methods

- (void)maybeAutoscrollForSnapshot:(UIImageView *)snapshot
{

    _autoscrollDistance = 0;
    
    if (CGRectGetMaxY(snapshot.frame) < self.contentSize.height )
    {
        // only autoscroll if the content is larger than the view
        if (self.contentSize.height > self.frame.size.height)
        {
            // only autoscroll if the thumb is overlapping the thumbScrollView
            if (CGRectIntersectsRect([snapshot frame], [self bounds]))
            {
                float distanceFromTop = _latestTouchPoint.y - CGRectGetMinY(self.bounds);
                float distanceFromBottom = CGRectGetMaxY(self.bounds) - _latestTouchPoint.y;
                
                if (distanceFromTop < kAutoScrollingThreshold) {
                    _autoscrollDistance = [self autoscrollDistanceForProximityToEdge:distanceFromTop] * -1; // if scrolling up, distance is negative
                } else if (distanceFromBottom < kAutoScrollingThreshold) {
                    _autoscrollDistance = [self autoscrollDistanceForProximityToEdge:distanceFromBottom];
                }
            }
        }
    }
        
    // if no autoscrolling, stop and clear timer
    if (_autoscrollDistance == 0) {
        [_autoscrollTimer invalidate];
        _autoscrollTimer = nil;
    }
    // otherwise create and start timer (if we don't already have a timer going)
    else if (_autoscrollTimer == nil) {
        _autoscrollTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0)
                                                           target:self
                                                         selector:@selector(autoscrollTimerFired:)
                                                         userInfo:snapshot
                                                          repeats:YES];
    }
}

- (float)autoscrollDistanceForProximityToEdge:(float)proximity {
    // the scroll distance grows as the proximity to the edge decreases, so that moving the thumb
    // further over results in faster scrolling.
    return ceilf((kAutoScrollingThreshold - proximity) / 5.0);
}

- (void)legalizeAutoscrollDistance {
    // makes sure the autoscroll distance won't result in scrolling past the content of the scroll view
    float minimumLegalDistance = ([self contentOffset].y + self.contentInset.top) * -1;
    float maximumLegalDistance = [self contentSize].height - ([self frame].size.height + [self contentOffset].y);
    _autoscrollDistance = MAX(_autoscrollDistance, minimumLegalDistance);
    _autoscrollDistance = MIN(_autoscrollDistance, maximumLegalDistance);
}

- (void)autoscrollTimerFired:(NSTimer*)timer {
//    NSLog(@"autoscrolling: %.2f",_autoscrollDistance);
    [self legalizeAutoscrollDistance];
    // autoscroll by changing content offset
    CGPoint contentOffset = [self contentOffset];
    contentOffset.y += _autoscrollDistance;
    [self setContentOffset:contentOffset];
    
    // adjust thumb position so it appears to stay still
    UIImageView *snapshot = (UIImageView *)[timer userInfo];
    snapshot.center = CGPointMake(snapshot.center.x, snapshot.center.y + _autoscrollDistance);
//    [snapshot moveByOffset:CGPointMake(_autoscrollDistance, 0)];
}

#pragma mark -

@end

@implementation ProxyDataSource
@synthesize movingIndexPath = _movingIndexPath;
@synthesize dataSource = _dataSource;

-(id)initWithDataSource:(id<UITableViewDataSource>)datasource
{
    if(self = [super init])
    {
        _dataSource = datasource;
        _proxyObject = datasource;
    }
    return self;
}

#pragma mark UITableViewDataSource

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // if there are no cells in section we must fake one so that is will be possible to insert a row
    NSInteger rows = [_dataSource tableView:tableView numberOfRowsInSection:section];
    return rows == 0 ? 1 : rows;
}

-(void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    NSInteger rows = [_dataSource tableView:tableView numberOfRowsInSection:destinationIndexPath.section];
    if(rows == 0)
    {
        // it's a fake cell, remove it
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:destinationIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        [tableView endUpdates];
    }

    if ([_dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)])
        [_dataSource tableView:tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
    
    // if the source section is empty after the update, a fake row must be inserted
    rows = [_dataSource tableView:tableView numberOfRowsInSection:sourceIndexPath.section];
    if(rows == 0)
    {
        [tableView beginUpdates];
        [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:sourceIndexPath] withRowAnimation:UITableViewRowAnimationNone];
        [tableView endUpdates];
    }
    
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL updated = NO;
    if(UITableViewCellEditingStyleDelete == editingStyle)
    {
        // if there source section will be empty after the update, a fake row must be inserted
        NSInteger rows = [_dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
        if(rows == 1)
        {
            [tableView beginUpdates];
            [_dataSource tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
            [tableView endUpdates];
            updated = YES;
        }
    }
    
    if(!updated)
        [_dataSource tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
    
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger rows = [_dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
    
    if(![indexPath isEqual:_movingIndexPath] && rows != 0)
    {
        return [_dataSource performSelector:@selector(tableView:cellForRowAtIndexPath:) withObject:tableView withObject:indexPath];
    }

    static NSString *CellIdentifier = @"EmptyCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if(!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
    }
    return cell;
}

#pragma mark -

@end

@implementation ProxyDelegate

-(id)initWithDelegate:(id<UITableViewDelegate>)delegate
{
    if(self = [super init])
    {
        _delegate = delegate;
        _proxyObject = delegate;
    }
    return self;
}

#pragma mark UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger count = [((ProxyDataSource *)tableView.dataSource).dataSource tableView:tableView numberOfRowsInSection:indexPath.section];

    CGFloat height = 0;
    if(count > 0)
        if ([_delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)])
            height = [_delegate tableView:tableView heightForRowAtIndexPath:indexPath];
        else
            height = tableView.rowHeight;
    else if([_delegate respondsToSelector:@selector(tableView:heightForEmptySection:)])
        height = [((NSObject<DragAndDropTableViewDelegate> *)_delegate) tableView:(DragAndDropTableView *)tableView heightForEmptySection:indexPath.section];
    else
        height = 0;

    return height;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger rows = [((ProxyDataSource *)tableView.dataSource).dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
    
    // you can't edit/delete the place holder cells
    if(rows == 0)
        return UITableViewCellEditingStyleNone;
    else if([_delegate respondsToSelector:@selector(tableView:editingStyleForRowAtIndexPath:)])
        return [_delegate tableView:tableView editingStyleForRowAtIndexPath:indexPath];
    else
    {
        // from iOS7+ UITableView.h: "Allows customization of the editingStyle for a particular cell located at 'indexPath'. If not implemented, all editable cells will have UITableViewCellEditingStyleDelete set for them when the table has editing property set to YES."
        // the thing is, this overrides tableView:canEditRowAtIndexPath: from UITableViewDataSource and you *can* delete rows without switching the tableView into editing mode first
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell.editing || tableView.isEditing)
            return UITableViewCellEditingStyleDelete;
      
        // from UITableView.h: Individual rows can opt out of having the -editing property set for them. If not implemented, all rows are assumed to be editable.
        BOOL respondsToCanEdit = [_delegate respondsToSelector:@selector(tableView:canEditRowAtIndexPath:)];
        if (!respondsToCanEdit ||
            (respondsToCanEdit && [((NSObject<UITableViewDataSource> *)_delegate) tableView:tableView canEditRowAtIndexPath:indexPath])) {
            return UITableViewCellEditingStyleDelete;
        }
      
        return UITableViewCellEditingStyleNone;
    }
    
}

#pragma mark -

@end

@implementation Proxy

-(void)forwardInvocation:(NSInvocation *)invocation {
	if (!_proxyObject) {
		[self doesNotRecognizeSelector: [invocation selector]];
	}
	[invocation invokeWithTarget:_proxyObject];
}

-(NSMethodSignature*)methodSignatureForSelector:(SEL)selector {
	NSMethodSignature *signature = [super methodSignatureForSelector:selector];
	if (! signature) {
		signature = [_proxyObject methodSignatureForSelector:selector];
	}
	return signature;
}

-(BOOL)respondsToSelector:(SEL)aSelector
{
    return [super respondsToSelector:aSelector] || (_proxyObject && [_proxyObject respondsToSelector:aSelector]);
}

#pragma mark -
@end
