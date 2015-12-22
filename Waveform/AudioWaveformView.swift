//
//  AudioWaveformView.swift
//  Waveform
//
//  Created by developer on 18/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIControl

final
class AudioWaveformView: UIView, _AudioWaveformView {
    
    weak var dataSource: AudioWaveformViewDataSource?
    var lineColor: UIColor = .blackColor() {
        didSet{
            self.pathLayer.strokeColor = lineColor.CGColor
        }
    }
    var identifier: String = ""
    
    private var drawedPulsesCount = 0
    private var pathLayer: CAShapeLayer!
    private var maxPulse: Int16 = 0 // ???: duplicate logic
    
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
        self.pathLayer.lineWidth       = 1.0/UIScreen.mainScreen().scale
        self.layer.addSublayer(self.pathLayer)
        self.pathLayer.frame           = self.bounds

        self.pathLayer.shouldRasterize     = true
        self.pathLayer.drawsAsynchronously = true
        self.pathLayer.rasterizationScale  = UIScreen.mainScreen().scale
    }
    
    func redrawPulses() {

        let loadedPulsesCount = self.dataSource!.currentPulsesCount
        
        if loadedPulsesCount < drawedPulsesCount {
            fatalError()
        }
        
        if loadedPulsesCount == drawedPulsesCount {
            return
        }
        self.normalizeIfNeeded()
        self.appendNewPathToPathLayer()
        self.drawedPulsesCount = loadedPulsesCount
    }
    
    private func appendNewPathToPathLayer() {

        let currentPath = CGPathCreateMutableCopy(self.pathLayer.path) ?? CGPathCreateMutable()
        let path        = self.newPathPart()
        
        CGPathAddPath(currentPath, nil, path)
        
        self.pathLayer.path = currentPath
    }
    
    private func newPathPart() -> CGPathRef {
        let loadedPulsesCount = self.dataSource!.currentPulsesCount
        let mPath = CGPathCreateMutable()

        for index in self.drawedPulsesCount..<loadedPulsesCount {
            let pulsesMax = self.dataSource!.pulseAtIndex(index)
            
            let xAdjustment = CGFloat(1)
            let yAdjustment = self.pathLayer.bounds.height/CGFloat(INT16_MAX)/2
            CGPathMoveToPoint(   mPath, nil, CGFloat(index)/xAdjustment, self.pathLayer.bounds.midY - CGFloat(pulsesMax)*yAdjustment)
            CGPathAddLineToPoint(mPath, nil, CGFloat(index)/xAdjustment, self.pathLayer.bounds.midY + CGFloat(pulsesMax)*yAdjustment)
        }
        return mPath
    }
    
    private func normalizeIfNeeded() {
        let globalMax = self.dataSource!.maxPulse
        if self.maxPulse < globalMax {
            self.maxPulse = globalMax
            self.pathLayer.transform = CATransform3DMakeScale(1.0, CGFloat(INT16_MAX)/CGFloat(maxPulse), 1.0)
        }
    }
    
}
