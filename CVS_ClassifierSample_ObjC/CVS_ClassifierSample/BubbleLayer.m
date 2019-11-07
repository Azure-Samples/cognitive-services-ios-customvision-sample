// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <UIKit/UIKit.h>
#import <CoreText/CTFont.h>
#import "BubbleLayer.h"
#import "BubbleLabelLayer.h"

@interface BubbleLayer ()

@property (strong, nonatomic) BubbleLabelLayer *layerLabel;

@end

@implementation BubbleLayer

- (instancetype)init {
    self = [super init];
    if (self) {
        _layerLabel = [[BubbleLabelLayer alloc] init];
        _font = [UIFont fontWithName:@"Helvetica-Bold" size:24.0];
        _textColor = [UIColor whiteColor];
        _paddingHorizontal = 25.0;
        _paddingVertical = 10.0;
        _maxWidth = 300.0;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string {
    self = [self init];
    if (self) {
        _string = string;

        // default values (can be changed by caller)
        self.backgroundColor = [UIColor colorWithRed:1.0 green:0.0 blue:217.0/255.0 alpha:1.0].CGColor;
        self.borderColor = [UIColor whiteColor].CGColor;
        self.borderWidth = 3.5;
        
        self.contentsScale = [UIScreen mainScreen].scale;
        self.allowsEdgeAntialiasing = YES;
        
        self.layerLabel.string = self.string;
        self.layerLabel.font = (__bridge CTFontRef)self.font;
        self.layerLabel.fontSize = self.font.pointSize;
        self.layerLabel.foregroundColor = self.textColor.CGColor;
        self.layerLabel.alignmentMode = kCAAlignmentCenter;
        self.layerLabel.contentsScale = [UIScreen mainScreen].scale;
        self.layerLabel.allowsFontSubpixelQuantization = YES;
        self.layerLabel.wrapped = YES;
        [self.layerLabel updatePreferredSizeWithMaxWidth:self.maxWidth - self.paddingHorizontal * 2];
        CGSize layerLabelSize = self.layerLabel.preferredFrameSize;
        self.layerLabel.frame = CGRectMake(self.paddingHorizontal, self.paddingVertical, layerLabelSize.width, layerLabelSize.height);
        [self addSublayer:self.layerLabel];
    }
    return self;
}

- (void)setString:(NSString *)string {
    _string = string;
    if (string == nil) {
        self.opacity = 0.0;
    }
    else {
        self.layerLabel.string = string;
        self.opacity = 1.0;
    }
    [self setNeedsLayout];
}

- (void)setFont:(UIFont *)font {
    _font = font;
    self.layerLabel.font = (__bridge CTFontRef)self.font;
    self.layerLabel.fontSize = self.font.pointSize;
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = textColor;
    self.layerLabel.foregroundColor = textColor.CGColor;
}

- (void)setPaddingHorizontal:(CGFloat)paddingHorizontal {
    _paddingHorizontal = paddingHorizontal;
    [self setNeedsLayout];
}

- (void)setPaddingVertical:(CGFloat)paddingVertical {
    _paddingVertical = paddingVertical;
    [self setNeedsLayout];
}

- (void)setMaxWidth:(CGFloat)maxWidth {
    _maxWidth = maxWidth;
    [self setNeedsLayout];
}

- (void)layoutSublayers {
    [self.layerLabel updatePreferredSizeWithMaxWidth:self.maxWidth - self.paddingHorizontal * 2];

    CGSize preferredSize = [self preferredFrameSize];
    CGSize diffSize = CGSizeMake(self.frame.size.width - preferredSize.width,
                                 self.frame.size.height - preferredSize.height);
    self.frame = CGRectMake(self.frame.origin.x + diffSize.width / 2,
                            self.frame.origin.y + diffSize.height / 2,
                            preferredSize.width, preferredSize.height);
    self.cornerRadius = self.frame.size.height / 2;
    
    self.layerLabel.frame = CGRectMake(0, self.paddingVertical, self.frame.size.width, self.frame.size.height);
}

- (CGSize)preferredFrameSize {
    CGSize layerLabelSize = self.layerLabel.preferredFrameSize;
    return CGSizeMake(layerLabelSize.width + self.paddingHorizontal * 2,
                      layerLabelSize.height + self.paddingVertical * 2);
}

@end
