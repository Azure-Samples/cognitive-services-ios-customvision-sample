// Copyright (c) Microsoft Corporation.  All rights reserved.

#import "BoundingBoxLabelLayer.h"

@implementation BoundingBoxLabelLayer

- (void)setPadding:(CGSize)padding
{
    _padding = padding;
    [self setNeedsLayout];
}

- (CGSize)preferredFrameSize
{
    CGSize textSize = super.preferredFrameSize;
    return CGSizeMake(
        textSize.width + self.padding.width,
        textSize.height + self.padding.height);
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, self.padding.width / 2.0f, self.padding.height / 2.0f);
    [super drawInContext:ctx];
    CGContextRestoreGState(ctx);
}

@end
