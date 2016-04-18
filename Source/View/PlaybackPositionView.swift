//
//  DVGPlaybackPositionView.swift
//  Denoise
//
//  Created by developer on 29/01/16.
//  Copyright © 2016 DENIVIP Group. All rights reserved.
//

import UIKit

class PlaybackPositionView: UIView {
    
    init() {
        super.init(frame: .zero)
        self.opaque = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.opaque = false
    }

    override func drawRect(rect: CGRect) {
        super.drawRect(rect)
        guard let relativePosition = self.position else {
            return
        }
        
        if relativePosition < 0 || relativePosition > 1 {
            return
        }
        
        let position = (self.bounds.width - lineWidth) * relativePosition + lineWidth/2
        
        guard let context = UIGraphicsGetCurrentContext() else {
            fatalError("No context")
        }
        
        CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor)
        CGContextSetLineWidth(context, lineWidth)
        
        
        
        let cursor = CGPathCreateMutable()
        CGPathMoveToPoint(cursor, nil, position, 0)
        CGPathAddLineToPoint(cursor, nil, position, self.bounds.height)
        CGContextAddPath(context, cursor)
        
        CGContextStrokePath(context)
        
    }
    
    /// Value from 0 to 1
    /// Setting value causes setNeedsDisplay method call
    /// Setting nil causes removing cursor
    var position: CGFloat? {
        didSet { self.setNeedsDisplay() }
    }
    var lineColor = UIColor.whiteColor()
    var lineWidth: CGFloat = 2.0
}
