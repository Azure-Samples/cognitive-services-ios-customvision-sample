// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <UIKit/UIKit.h>
#import "BubbleLabelLayer.h"

@interface BubbleLabelLayer ()

@property (assign, nonatomic) CGSize preferredSize;

@end

@implementation BubbleLabelLayer

- (void)setPreferredSize:(CGSize)preferredSize {
    _preferredSize = preferredSize;
    [self setNeedsLayout];
}

- (void)updatePreferredSizeWithMaxWidth:(CGFloat)maxWidth {
    NSString *string = (NSString *)self.string;
    if (!string) {
        self.preferredSize = CGSizeZero;
        return;
    }
    
    UIFont *font = (UIFont *)self.font;
    if (!font) {
        self.preferredSize = CGSizeZero;
        return;
    }

    NSAttributedString *nsString = [[NSAttributedString alloc] initWithString:string attributes:@{NSFontAttributeName: font}];
    CGRect fontBounds = [nsString boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                            context:nil];
    fontBounds.size.height += fabs(font.descender);
    self.preferredSize = fontBounds.size;
}

- (CGSize)preferredFrameSize {
    return self.preferredSize;
}

@end
