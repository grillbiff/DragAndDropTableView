//
//  UIView+Snapshot.m
//  DragAndDropTableView
//
//  Created by Erik Johansson on 4/1/13.
//  Copyright (c) 2013 Erik Johansson. All rights reserved.
//

#import "UIView+Snapshot.h"
#import <QuartzCore/QuartzCore.h>

@implementation UIView (Snapshot)
-(UIImage *)snapshotImageWithClearedRect:(CGRect)rect
{
    CGRect frame = [self bounds];
    
    if ([[UIScreen mainScreen] scale] == 2.0) {
        UIGraphicsBeginImageContextWithOptions(frame.size, NO, 2.0);
    } else {
        UIGraphicsBeginImageContext(frame.size);
    }
    
    [[self layer] renderInContext:UIGraphicsGetCurrentContext()];
    
    if(!CGRectIsNull(rect))
    {
        // clear rect in the context
        CGContextClearRect(UIGraphicsGetCurrentContext(), rect);
        //CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), [UIColor orangeColor].CGColor);
        //CGContextFillRect(UIGraphicsGetCurrentContext(), rect);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
 
    return image;
}

-(UIImage* )snapshotImage
{
    return [self snapshotImageWithClearedRect:CGRectNull];
}
@end
