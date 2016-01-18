//
//  AudioWaveformPlotView.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIView

protocol AudioWaveformViewDataSource: class {
    var identifier: String { get }
    var bounds: CGSize { get }
    var pointsCount: Int { get }
    func updateGeometry()
    func pointAtIndex(index: Int) -> CGPoint
}

protocol AudioWaveformPlotDataSource: class {
    var onPlotUpdate: () -> () { get set }
    var waveformDataSourcesCount: Int { get }
    func waveformDataSourceAtIndex(index: Int) -> AudioWaveformViewDataSource
}
protocol AudioWaveformPlotDelegate: class {
    var scale: CGFloat { get }
    var start: CGFloat { get }
    func zoomAt(zoomAreaCenter: CGFloat, relativeScale: CGFloat)
    func moveByDistance(relativeDeltaX: CGFloat)
}