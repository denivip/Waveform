//
//  Plot.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIControl

class Plot: UIView {
    
    weak var dataSource: PlotDataSource? {
        didSet {
            identifier = dataSource?.identifier ?? ""
        }
    }
    
    var lineColor: UIColor = .blackColor() {
        didSet{
//            self.pathLayer.strokeColor = lineColor.CGColor
        }
    }

    var identifier: String = ""
    
    private var pathLayer: CAShapeLayer!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.opaque = false
    }
    
    convenience init(){
        self.init(frame: CGRectZero)
        self.opaque = false
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.opaque = false
    }
    
    func setupPathLayer() {
        
        self.pathLayer             = CAShapeLayer()
        self.pathLayer.strokeColor = UIColor.blackColor().CGColor
        self.pathLayer.lineWidth   = 1.0
        self.layer.addSublayer(self.pathLayer)
        
        self.pathLayer.drawsAsynchronously = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.redraw()
    }
    
    func redraw() {
        self.setNeedsDisplay()
    }
    
    override func drawRect(rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        CGContextSetLineWidth(context, 1)///UIScreen.mainScreen().scale)
        CGContextAddPath(context, self.newPathPart())
        CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor)
        CGContextSetInterpolationQuality(context, .None);
        CGContextSetAllowsAntialiasing(context, false);
        CGContextSetShouldAntialias(context, false);
        CGContextStrokePath(context)
    }
    
    private func newPathPart() -> CGPathRef {
        
        let lineWidth: CGFloat = 1
        
        guard let dataSource = self.dataSource else {
            return CGPathCreateMutable()
        }
        
        let currentCount = dataSource.pointsCount
        let sourceBounds = dataSource.dataSourceFrame.size
        
        let mPath        = CGPathCreateMutable()
        CGPathMoveToPoint(mPath, nil, 0, self.bounds.midY - lineWidth/2)
        
        let wProportion = self.bounds.size.width / sourceBounds.width
        let hPropostion = self.bounds.size.height / sourceBounds.height
        
        for index in 0..<currentCount {
            let point         = dataSource.pointAtIndex(index)
            let adjustedPoint = CGPoint(
                x: point.x * wProportion,
                y: point.y * hPropostion / 2.0)
            
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY - adjustedPoint.y)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY + adjustedPoint.y)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY)
        }
        
        CGPathAddLineToPoint(mPath, nil, 0.0, self.bounds.midY)
        CGPathCloseSubpath(mPath)
        return mPath
    }
}


