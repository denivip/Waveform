//
//  AudioWaveformPlot.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit

final
class AudioWaveformPlot: UIView {
    
    var containerView: UIView!
    var pinch: UIPinchGestureRecognizer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.addContainerView()
        self.addGestures()
    }
    
    func addContainerView() {
        let containerView = UIView()
        // FIXME: do right work with constraints
        containerView.frame = self.bounds
        self.addSubview(containerView)
        self.containerView = containerView
    }
    
    func addGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: "handlePinch:")
        self.addGestureRecognizer(pinch)
        self.pinch = pinch
    }
    
    var waveformViews = [AudioWaveformView]()
    var displayLink: CADisplayLink?
    
    var scale = CGFloat(1)
    
    @objc(handlePinch:)
    func handlePinch(pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .Began: ()
        case .Cancelled, .Ended, .Failed, .Possible:
            self.scale *= pinch.scale
            normalizeScale(&self.scale)
        case .Changed:
            var scale = self.scale * pinch.scale
            normalizeScale(&scale)
            let layer = self.containerView.layer

            //TODO: zoom relative to pinch location
            layer.transform = CATransform3DMakeScale(scale, 1.0, 1.0)
        }
    }
    
    func normalizeScale(inout scale: CGFloat) {
        scale = max(1.0, min(scale, 10.0))
    }
}

extension AudioWaveformPlot: _AudioWaveformPlot {
    
    func addWaveformViewWithId(identifier: String) -> _AudioWaveformView {
        
        let audioWaveformView = AudioWaveformView(frame: self.bounds)
        audioWaveformView.identifier = identifier
        
        self.waveformViews.append(audioWaveformView)
        self.containerView.addSubview(audioWaveformView)
        
        return audioWaveformView
    }
    
    func redraw() {
        for waveformView in self.waveformViews {
            waveformView.redrawPulses()
        }
    }
    
    func startSynchingWithDataSource() {
        if self.displayLink != nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }
        let displayLink = CADisplayLink.init(target: self, selector: "redraw")
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        self.displayLink = displayLink
    }
    
    func stopSynchingWithDataSource() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}