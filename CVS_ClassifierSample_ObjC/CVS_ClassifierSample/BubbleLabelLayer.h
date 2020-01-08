// Copyright (c) Microsoft Corporation.  All rights reserved.

#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface BubbleLabelLayer : CATextLayer

- (void)updatePreferredSizeWithMaxWidth:(CGFloat)maxWidth;

@end

NS_ASSUME_NONNULL_END
