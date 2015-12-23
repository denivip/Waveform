//
//  AudioWaveformPlotView.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIView

protocol _AudioWaveformPlot: class {
    func addWaveformViewWithId(identifier: String) -> _AudioWaveformView
    func startSynchingWithDataSource()
    func stopSynchingWithDataSource()
    func redraw()
}

protocol _AudioWaveformView: class {
    var identifier: String { get }
    weak var dataSource: AudioWaveformViewDataSource? { get set }
    var lineColor: UIColor { get set }
}

protocol AudioWaveformViewDataSource: class {
    var maxPulse: Int16 { get }
    var currentPulsesCount: Int { get }
    var totalPulsesCount: Int { get }
    
    func pulseAtIndex(index: Int) -> Int16
}

protocol AudioWaveformPlotDataSource: class {}