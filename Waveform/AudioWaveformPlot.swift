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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    var waveformViews = [AudioWaveformView]()
    var displayLink: CADisplayLink?
    
    func redrawPulses() {
        for waveformView in self.waveformViews {
            waveformView.redrawPulses()
        }
    }
    
    func startSynchingWithDataSource() {
        if self.displayLink != nil {
            fatalError()
        }
        let displayLink = CADisplayLink.init(target: self, selector: "redrawPulses")
        displayLink.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        self.displayLink = displayLink
    }
    
    func stopSynchingWithDataSource() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
}

extension AudioWaveformPlot: _AudioWaveformPlot {
    
    func addWaveformViewWithId(identifier: String) -> _AudioWaveformView {
        
        let audioWaveformView = AudioWaveformView(frame: self.bounds)
        audioWaveformView.identifier = identifier
        
        self.waveformViews.append(audioWaveformView)
        self.addSubview(audioWaveformView)
        
        return audioWaveformView
    }
}