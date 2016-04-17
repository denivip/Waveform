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
    var onGeometryUpdate: () -> () {set get}
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

protocol AudioWaveformPlotViewModelDelegate: class {
    func plotMoved(scale: CGFloat, start: CGFloat)
}

protocol ChannelSource: class, Identifiable {
    var channelsCount: Int { get }
    var onChannelsChanged: (ChannelSource) -> () { get set }
    func channelAtIndex(index: Int) -> Channel
}

protocol AbstractChannel: class, Identifiable {
    var totalCount: Int { get }
    var count: Int { get }
    var identifier: String { get }
    var maxValue: Double { get }
    var minValue: Double { get }
    
    subscript(index: Int) -> Double { get }
    func handleValue<U: NumberType>(value: U)
}

protocol AudioSamplesHandler: class {
    func willStartReadSamples(estimatedSampleCount estimatedSampleCount: Int)
    func didStopReadSamples(count: Int)
    func handleSamples(samplesContainer: AudioSamplesContainer)
}

extension AudioSamplesHandler {
    func handleSamples(buffer: UnsafePointer<Int16>, bufferLength: Int, numberOfChannels: Int) {
        return self.handleSamples(AudioSamplesContainer.init(buffer: buffer, length: bufferLength, numberOfChannels: numberOfChannels))
    }
}

protocol Identifiable {
    var identifier: String { get }
}
