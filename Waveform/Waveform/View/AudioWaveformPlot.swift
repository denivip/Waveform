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
            self.updateWaveforms()
        }
    }
    
    weak var viewModel: protocol<AudioWaveformPlotDelegate, AudioWaveformPlotDataSource>? {
        didSet {
            self.delegate   = viewModel
            self.dataSource = viewModel
            viewModel?.onPlotUpdate = self.updateWaveforms
        }
    }
    
    func updateWaveforms() {
        if let newDataSource = dataSource {
            for index in 0..<newDataSource.waveformDataSourcesCount {
                let waveformDataSource = newDataSource.waveformDataSourceAtIndex(index)
                
                guard let view = self.waveformWithIdentifier(waveformDataSource.identifier) else  {
                    let view = self.addWaveformViewWithDataSource(waveformDataSource)
                    continue
                }
                view.dataSource = waveformDataSource
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
    
    private func setup() {
        self.addContainerView()
        self.addGestures()
    }
    
    func addContainerView() {
        let containerView = UIView()
        self.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.attachBoundsOfSuperview()
        self.containerView = containerView
    }
    
    func addGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: "handlePan:")
        self.addGestureRecognizer(pan)
        self.pan = pan
        
        let pinch = UIPinchGestureRecognizer(target: self, action: "handlePinch:")
        self.addGestureRecognizer(pinch)
        self.pinch = pinch
    }
    
    func handlePan(gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .Changed:
            let deltaX         = gesture.translationInView(gesture.view).x
            let relativeDeltaX = deltaX/gesture.view!.bounds.width
            self.delegate?.moveByDistance(relativeDeltaX)
            gesture.setTranslation(.zero, inView: gesture.view)
        default:()
        }
    }
    
    func handlePinch(gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .Changed:
            let scale     = gesture.scale
            let locationX = gesture.locationInView(gesture.view).x
            let relativeLocation = locationX/gesture.view!.bounds.width
            self.delegate?.zoomAt(relativeLocation, relativeScale: scale)
            gesture.scale = 1.0
        case .Ended:
            print(self.viewModel!.start, self.viewModel!.scale)
        default:()
        }
    }
    
    var waveformViews = [AudioWaveformView]()
    var displayLink: CADisplayLink?
}

extension AudioWaveformPlot {
    
    func addWaveformViewWithDataSource(dataSource: AudioWaveformViewDataSource) -> AudioWaveformView {
        
        let audioWaveformView = AudioWaveformView(frame: self.bounds)
        audioWaveformView.dataSource = dataSource
        
        self.waveformViews.append(audioWaveformView)
        
        self.containerView.addSubview(audioWaveformView)
        
        audioWaveformView.translatesAutoresizingMaskIntoConstraints = false
        audioWaveformView.attachBoundsOfSuperview()
        
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
            waveformView.dataSource?.updateGeometry()//redraw()
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