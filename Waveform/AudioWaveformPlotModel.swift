//
//  AudioWaveformPlotModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation
import UIKit.UIColor

class AudioWaveformPlotModel: NSObject, AudioWaveformPlotDataSource {
    
    private var viewModels = [AudioWaveformViewModel]()
    
    override init() {
        super.init()
    }

    var scale: CGFloat = 1.0
    var start: CGFloat = 0.0
    var onPlotUpdate: () -> () = {}
    var dataSources = [ChannelSource]()

    var waveformDataSourcesCount: Int { return self.viewModels.count }
    func waveformDataSourceAtIndex(index: Int) -> AudioWaveformViewDataSource {
        return self.viewModels[index]
    }
    
    func addChannelSource(cSource: ChannelSource) {
        self.dataSources.append(cSource)
        for index in 0..<cSource.channelsCount {
            let vm       = AudioWaveformViewModel()
            vm.channel   = cSource.channelAtIndex(index)
            vm.plotModel = self
            self.viewModels.append(vm)
        }
        self.onPlotUpdate()
    }
    
    func resetChannelsFromDataSources() {
        var channels = [ChannelProtocol]()
        for dataSource in self.dataSources {
            for index in 0..<dataSource.channelsCount {
                let channel = dataSource.channelAtIndex(index)
                channels.append(channel)
            }
        }

        assert(channels.count == viewModels.count)

        for index in channels.indices {
            self.viewModels[index].channel = channels[index]
        }
    }
}

extension AudioWaveformPlotModel: AudioWaveformPlotDelegate {
    func zoom(start start: CGFloat, scale: CGFloat) {
        self.scale = scale
        self.start = start
        for viewModel in self.viewModels {
            viewModel.updateGeometry()
        }
    }
    
    func zoomAt(zoomAreaCenter: CGFloat, relativeScale: CGFloat) {
        let newScale = max(1.0, relativeScale * self.scale)
        var start    = self.start + zoomAreaCenter * (1/self.scale - 1/newScale)
        start        = max(0, min(start, 1 - 1/newScale))
        self.zoom(start: start, scale: newScale)
    }
    
    func moveToPosition(start: CGFloat) {
        self.start = max(0, min(start, 1 - 1/scale))
        for viewModel in self.viewModels {
            viewModel.updateGeometry()
        }
    }
    
    func moveByDistance(relativeDeltaX: CGFloat) {
        let relativeStart = self.start - relativeDeltaX / self.scale
        self.moveToPosition(relativeStart)
    }
}

protocol ChannelSource {
    var identifier: String { get }
    func identifierForLogicProviderType(type: LogicProvider.Type) -> String
    var channelsCount: Int { get }
    func channelAtIndex(index: Int) -> ChannelProtocol
    var onChannelsChanged: (ChannelSource) -> () { get set }
}