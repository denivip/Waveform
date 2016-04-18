//
//  DiagramView.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import UIKit.UIView

protocol PlotDataSource: class {
    var identifier: String { get }
    var dataSourceFrame: CGRect { get }
    var pointsCount: Int { get }
    var needsRedraw: Bool { get set }
    func updateGeometry()
    func pointAtIndex(index: Int) -> CGPoint
}

protocol DiagramDataSource: class {
    var geometry: DiagramGeometry { get }
    var onPlotUpdate: () -> () { get set }
    var plotDataSourcesCount: Int { get }
    func plotDataSourceAtIndex(index: Int) -> PlotDataSource
}

protocol DiagramDelegate: class {
    func zoomAt(zoomAreaCenter: CGFloat, relativeScale: CGFloat)
    func moveByDistance(relativeDeltaX: CGFloat)
}

protocol DVGDiagramDelegate: class, DiagramDelegate {
    func diagramDidSelect(dataRange: DataRange)
}

protocol ChannelSource: class {
    var channelsCount: Int { get }
    var onChannelsChanged: () -> () { get set }
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