//
//  UIView+Snapshot.h
//  DragAndDropTableView
//
//  Created by Erik Johansson on 4/1/13.
//  Copyright (c) 2013 Erik Johansson. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Snapshot)
-(UIImage *)snapshotImageWithClearedRect:(CGRect)rect;
-(UIImage *)snapshotImage;
@end
