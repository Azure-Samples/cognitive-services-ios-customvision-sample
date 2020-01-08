// Copyright (c) Microsoft Corporation.  All rights reserved.

import UIKit

class BoundingBoxLabelLayer: CATextLayer {

    public var padding = CGSize.zero {
        didSet {
            needsLayout()
        }
    }

    override func preferredFrameSize() -> CGSize {

        let textSize = super.preferredFrameSize();
        return CGSize.init(
            width: textSize.width + padding.width,
            height: textSize.height + padding.height);
    }
    
    override func draw(in ctx: CGContext) {

        ctx.saveGState()
        ctx.translateBy(x: padding.width / 2.0, y: padding.height / 2.0)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
}
