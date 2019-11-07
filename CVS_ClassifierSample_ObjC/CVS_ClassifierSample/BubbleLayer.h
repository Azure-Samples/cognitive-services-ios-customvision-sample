// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BubbleLayer : CALayer

@property (copy, nonatomic, nullable) NSString *string;
@property (strong, nonatomic) UIFont *font;
@property (strong, nonatomic) UIColor *textColor;
@property (assign, nonatomic) CGFloat paddingHorizontal;
@property (assign, nonatomic) CGFloat paddingVertical;
@property (assign, nonatomic) CGFloat maxWidth;

- (instancetype)initWithString:(NSString *)string;
@end

NS_ASSUME_NONNULL_END
