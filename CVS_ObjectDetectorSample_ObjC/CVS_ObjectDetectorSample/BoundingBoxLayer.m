// Copyright (c) Microsoft Corporation.  All rights reserved.

#import "BoundingBoxLayer.h"
#import "BoundingBoxLabelLayer.h"

@interface BoundingBoxLayer ()

@property (strong, nonatomic) BoundingBoxLabelLayer *labelLayer;

@end


@implementation BoundingBoxLayer

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.backgroundColor = [[UIColor clearColor] CGColor];
        self.borderColor = [[UIColor whiteColor] CGColor];
        self.borderWidth = 4.0f;
        
        self.labelLayer = [[BoundingBoxLabelLayer alloc] init];
        self.labelLayer.backgroundColor = [[UIColor whiteColor] CGColor];
        self.labelLayer.foregroundColor = [[UIColor blackColor] CGColor];
        self.labelLayer.contentsScale = [[UIScreen mainScreen] scale];
        self.labelLayer.font = (__bridge CFStringRef)[[UIFont systemFontOfSize:12] fontName];
        self.labelLayer.fontSize = 14.0f;
        self.labelLayer.alignmentMode = kCAAlignmentLeft;
        self.labelLayer.padding = CGSizeMake(16.0f, 8.0f);

        if (@available(iOS 11.0, *)) {
            self.cornerRadius = 6.0f;
            self.maskedCorners = kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;

            self.labelLayer.cornerRadius = 6.0f;
            self.labelLayer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
        }

        [self addSublayer:self.labelLayer];
    }
    return self;
}

- (void)setLabel:(NSString *)label
{
    _label = label;

    self.labelLayer.string = label;
    [self setNeedsLayout];
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    
    //
    
    self.borderColor = [color CGColor];
    self.labelLayer.backgroundColor = [color CGColor];
}

- (void)layoutSublayers
{
    CGSize labelSize = self.labelLayer.preferredFrameSize;
    self.labelLayer.frame = CGRectMake(0.0f, - labelSize.height + self.borderWidth, labelSize.width, labelSize.height);
}

@end
