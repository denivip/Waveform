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
    func identifierForLogicProviderType(type: LogicProvider.Type) -> String
    var channelsCount: Int { get }
    func channelAtIndex(index: Int) -> AbstractChannel
    var onChannelsChanged: (ChannelSource) -> () { get set }
}

extension ChannelSource {
    func identifierForLogicProviderType(type: LogicProvider.Type) -> String {
        return self.identifier + "." + type.typeIdentifier
    }
}

protocol Identifiable {
    static var typeIdentifier: String { get }
    var identifier: String { get }
}

extension Identifiable {
    static var typeIdentifier: String { return "\(self)" }
    var identifier: String { return "\(self.dynamicType)" }
}