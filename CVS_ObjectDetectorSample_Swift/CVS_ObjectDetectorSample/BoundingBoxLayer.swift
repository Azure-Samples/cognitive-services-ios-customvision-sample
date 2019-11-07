// Copyright (c) Microsoft Corporation.  All rights reserved.

import UIKit

class BoundingBoxLayer: CALayer {

    var label: String? {
        didSet {
            labelLayer.string = label
            setNeedsLayout()
        }
    }
    
    var color: UIColor = UIColor.white {
        didSet {
            borderColor = color.cgColor
            labelLayer.backgroundColor = color.cgColor
        }
    }
    
    private var labelLayer = BoundingBoxLabelLayer()
    
    override init() {
        super.init()
        
        backgroundColor = UIColor.clear.cgColor
        borderColor = color.cgColor
        borderWidth = 4.0

        labelLayer.backgroundColor = color.cgColor
        labelLayer.foregroundColor = UIColor.black.cgColor
        labelLayer.contentsScale = UIScreen.main.scale
        labelLayer.font = UIFont.systemFont(ofSize: UIFont.systemFontSize).fontName as CFTypeRef
        labelLayer.fontSize = 14.0
        labelLayer.alignmentMode = CATextLayerAlignmentMode.left
        labelLayer.padding = CGSize.init(width: 16.0, height: 8.0)

        if #available(iOS 11.0, *) {
            cornerRadius = 6.0
            maskedCorners = [.layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner ]

            labelLayer.cornerRadius = 6.0
            labelLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        }

        addSublayer(labelLayer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {

        let labelSize = labelLayer.preferredFrameSize();
        labelLayer.frame = CGRect.init(
            x: 0.0,
            y: -labelSize.height + self.borderWidth,
            width: labelSize.width,
            height: labelSize.height);
    }

}
