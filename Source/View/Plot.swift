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
            self.pathLayer.fillColor = lineColor.CGColor
        }
    }

    var identifier: String = ""
    
    private var pathLayer: CAShapeLayer!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupPathLayer()
    }
    
    convenience init(){
        self.init(frame: CGRectZero)
        self.setupPathLayer()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupPathLayer()
    }
    
    func setupPathLayer() {
        
        self.pathLayer             = CAShapeLayer()
        self.pathLayer.fillColor   = UIColor.blackColor().CGColor
//        self.pathLayer.lineWidth   = 1.0
        self.layer.addSublayer(self.pathLayer)
        
        self.pathLayer.drawsAsynchronously = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.pathLayer.frame = self.bounds
        self.redraw()
    }
    
    func redraw() {
        self.appendNewPathToPathLayer()
    }
    
    private func appendNewPathToPathLayer() {
        self.pathLayer.path = self.newPathPart()
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
            
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x,               self.bounds.midY - lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x,               self.bounds.midY - adjustedPoint.y - lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x + lineWidth,   self.bounds.midY - adjustedPoint.y - lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x + lineWidth,   self.bounds.midY - lineWidth/2)
        }
        CGPathAddLineToPoint(mPath, nil, CGPathGetCurrentPoint(mPath).x, self.bounds.midY)
        for index in 0..<currentCount {
            let index = currentCount - index - 1
            let point         = dataSource.pointAtIndex(index)
            let adjustedPoint = CGPoint(
                x: point.x * wProportion,
                y: point.y * hPropostion / 2.0)
            
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x,               self.bounds.midY + lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x,               self.bounds.midY + adjustedPoint.y + lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x + lineWidth,   self.bounds.midY + adjustedPoint.y + lineWidth/2)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x + lineWidth,   self.bounds.midY + lineWidth/2)
        }
        
        CGPathAddLineToPoint(mPath, nil, 0.0, self.bounds.midY)
        CGPathCloseSubpath(mPath)
        return mPath
    }
}
