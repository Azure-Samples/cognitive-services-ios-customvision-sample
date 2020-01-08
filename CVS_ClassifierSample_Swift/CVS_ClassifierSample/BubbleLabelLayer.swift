// Copyright (c) Microsoft Corporation.  All rights reserved.

import UIKit

class BubbleLabelLayer : CATextLayer {
    
    private var preferedSize = CGSize.zero {
        didSet {
            needsLayout()
        }
    }
    
    func updatePreferredSize(maxWidth: CGFloat) {
        
        guard let string = self.string as? String else {
            //print("Trying to update label size without string")
            preferedSize = CGSize.zero
            return
        }
        
        guard let font = self.font as? UIFont else {
            print("Trying to update label size without font")
            preferedSize = CGSize.zero
            return
        }
        
        let nsString = NSAttributedString(string: string, attributes: [ .font : font ])
        var fontBounds = nsString.boundingRect(with: CGSize(width: maxWidth,
                                                            height: CGFloat.greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin],
                                               context: nil)
        fontBounds.size.height += abs(font.descender)
        preferedSize = fontBounds.size
    }
    
    override func preferredFrameSize() -> CGSize {
        return preferedSize
    }
}
