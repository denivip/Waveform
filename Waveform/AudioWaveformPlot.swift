//
//  AudioWaveformPlot.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit

class AudioWaveformPlot: UIView {
    
    var containerView: UIView!
    var pan: UIPanGestureRecognizer!
    var pinch: UIPinchGestureRecognizer!
    
    weak var delegate: AudioWaveformPlotDelegate?
    weak var dataSource: AudioWaveformPlotDataSource? {
        didSet{
            if let newDataSource = dataSource {
                for index in 0..<newDataSource.waveformDataSourcesCount {
                    let dataSource = newDataSource.waveformDataSourceAtIndex(index)
                    self.addWaveformViewWithDataSource(dataSource)
                }
            }
        }
    }
    
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
        self.addSubview(containerView)
        let views = ["view": containerView]
        containerView.translatesAutoresizingMaskIntoConstraints = false
        let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("|[view]|", options: [], metrics: nil, views: views)
        self.addConstraints(horizontalConstraints)
        let verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options: [], metrics: nil, views: views)
        self.addConstraints(verticalConstraints)
        self.containerView = containerView
    }
    
    func addGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: "pan:")
        self.addGestureRecognizer(pan)
        let pinch = UIPinchGestureRecognizer(target: self, action: "pinch:")
        self.addGestureRecognizer(pinch)
    }
    
    func pan(gesture: UIPanGestureRecognizer) {
        
        if delegate == nil { return }
        
        switch gesture.state {
        case .Changed:
            let deltaX                      = gesture.translationInView(gesture.view).x
            let relativeDeltaX              = deltaX/gesture.view!.bounds.width
            self.delegate?.moveByDistance(relativeDeltaX)
            gesture.setTranslation(.zero, inView: gesture.view)
        default:()
        }
    }
    
    var scale: CGFloat = 1.0
    
    func pinch(gesture: UIPinchGestureRecognizer) {
        if gesture.numberOfTouches() < 2 {
            return
        }
        
        switch gesture.state {
        case .Changed:
            let scale            = gesture.scale
            let locationX        = gesture.locationInView(gesture.view).x
            let relativeLocation = locationX/gesture.view!.bounds.width
            self.delegate?.zoomAt(relativeLocation, relativeScale: scale)
            gesture.scale = 1.0
        default:()
        }
    }
    
    //    override func layoutSubviews() {
    //        super.layoutSubviews()
    //        for v in self.waveformViews {
    //            v.setNeedsLayout()
    //        }
    //    }
    
    var waveformViews = [AudioWaveformView]()
    var displayLink: CADisplayLink?
}

extension AudioWaveformPlot {
    
    func addWaveformViewWithDataSource(dataSource: AudioWaveformViewDataSource) -> AudioWaveformView {
        
        let audioWaveformView = AudioWaveformView(frame: self.bounds)
        audioWaveformView.dataSource = dataSource
        
        self.waveformViews.append(audioWaveformView)
        
        audioWaveformView.translatesAutoresizingMaskIntoConstraints = false
        self.containerView.addSubview(audioWaveformView)
        
        let views = ["view": audioWaveformView]
        let horizontalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("|[view]|", options: [], metrics: nil, views: views)
        self.containerView.addConstraints(horizontalConstraints)
        let verticalConstraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|[view]|", options: [], metrics: nil, views: views)
        self.containerView.addConstraints(verticalConstraints)
        
        audioWaveformView.backgroundColor = UIColor.redColor().colorWithAlphaComponent(0.5)
        
        return audioWaveformView
    }
    
    func waveformWithIdentifier(identifier: String) -> AudioWaveformView? {
        for waveform in self.waveformViews {
            if waveform.identifier == identifier {
                return waveform
            }
        }
        return nil
    }
    
    func redraw() {
        for waveformView in self.waveformViews {
            waveformView.redraw()
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