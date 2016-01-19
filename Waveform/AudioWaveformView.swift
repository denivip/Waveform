//
//  AudioWaveformView.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIControl

class AudioWaveformView: UIView {
    
    weak var dataSource: AudioWaveformViewDataSource? {
        didSet {
            dataSource?.onGeometryUpdate = {
                self.appendNewPathToPathLayer()
            }
        }
    }
    
    var lineColor: UIColor = .blackColor() {
        didSet{
            self.pathLayer.strokeColor = lineColor.CGColor
        }
    }
    var identifier: String { return self.dataSource?.identifier ?? ""}
    
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
        
        self.pathLayer                 = CAShapeLayer()
        self.pathLayer.strokeColor     = UIColor.blackColor().CGColor
        self.pathLayer.lineWidth       = 1.0
        self.layer.addSublayer(self.pathLayer)
        
        //        self.pathLayer.shouldRasterize     = true
        self.pathLayer.drawsAsynchronously = true
        //        self.pathLayer.rasterizationScale  = UIScreen.mainScreen().scale
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
//        self.dataSource?.updateGeometry()        
        self.pathLayer.path = self.newPathPart()
    }
    
    private func newPathPart() -> CGPathRef {
        
        guard let dataSource = self.dataSource else {
            return CGPathCreateMutable()
        }
        
        let currentCount = dataSource.pointsCount
        let sourceBounds = dataSource.bounds
        
        let mPath        = CGPathCreateMutable()
        
        CGPathMoveToPoint(mPath, nil, 0, self.bounds.midY)
        
        for index in 0..<currentCount {
            let point         = dataSource.pointAtIndex(index)
            let adjustedPoint = CGPoint(
                x: point.x * self.bounds.size.width / sourceBounds.width,
                y: point.y * self.bounds.size.height / sourceBounds.height / 2.0)
            
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY - adjustedPoint.y)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY + adjustedPoint.y)
            CGPathAddLineToPoint(mPath, nil, adjustedPoint.x, self.bounds.midY)
        }
        CGPathMoveToPoint(mPath, nil, CGPathGetCurrentPoint(mPath).x, self.bounds.midY)
        
        return mPath
    }
}
