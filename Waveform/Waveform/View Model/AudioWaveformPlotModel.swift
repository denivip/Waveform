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
    
    weak var delegate: AudioWaveformPlotViewModelDelegate?
    
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
    
    func addChannelSource(channelsSource: ChannelSource) {
        
        self.dataSources.append(channelsSource)
        
//        for index in 0..<channelsSource.channelsCount {
//            
//            let channel         = channelsSource.channelAtIndex(index)
//            let viewModel       = AudioWaveformViewModel()
//            
//            viewModel.channel   = channel
//            viewModel.plotModel = self
//            
//            self.viewModels.append(viewModel)
//        }
        
        self.updateViewModelsForChannelsSource(channelsSource)
        
        channelsSource.onChannelsChanged = {
            [weak self, weak channelsSource] in
            if let channelsSource = channelsSource {
                self?.updateViewModelsForChannelsSource(channelsSource)
            }
        }
    }
    
    func resetChannelsFromDataSources() {
        for dataSource in self.dataSources {
            self.updateViewModelsForChannelsSource(dataSource)
        }
    }
    
    func updateViewModelsForChannelsSource(channelsSource: ChannelSource) {

        for index in 0..<channelsSource.channelsCount {
            
            let channel    = channelsSource.channelAtIndex(index)
            let identifier = channel.identifier
            
            if let viewModel = self.viewModelWithIdentifier(identifier) {
               
                viewModel.channel = channel
                viewModel.updateGeometry()
                
            } else {
                
                let viewModel       = AudioWaveformViewModel()
                viewModel.channel   = channel
                viewModel.plotModel = self
                self.viewModels.append(viewModel)
                
            }
        }
        self.onPlotUpdate()
    }
    
    func viewModelWithIdentifier(identifier: String) -> AudioWaveformViewModel? {
        for viewModel in self.viewModels {
            if viewModel.identifier == identifier {
                return viewModel
            }
        }
        return nil
    }

    func maxWafeformBounds() -> CGSize {
        var maxHeight: CGFloat = 0.1
        for dataSource in self.dataSources {
            for index in 0..<dataSource.channelsCount {
                let channel = dataSource.channelAtIndex(index)
                if CGFloat(channel.maxValue) > maxHeight {
                    maxHeight = CGFloat(channel.maxValue)
                }
            }
        }
        return CGSize(width: 1.0, height: maxHeight)
    }
    
    func absoluteRangeFromRelativeRange(range: DataRange) -> DataRange {
        return DataRange(location: Double(self.start) + range.location/Double(self.scale), length: range.length/Double(self.scale))
    }
}

extension AudioWaveformPlotModel: AudioWaveformPlotDelegate {
    func zoom(start start: CGFloat, scale: CGFloat) {
        self.scale = scale
        self.start = start
        self.delegate?.plotMoved(scale, start: start)
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
        self.start = max(0, min(start, 1 - 1/self.scale))
        self.delegate?.plotMoved(self.scale, start: self.start)
        for viewModel in self.viewModels {
            viewModel.updateGeometry()
        }
    }
    
    func moveByDistance(relativeDeltaX: CGFloat) {
        let relativeStart = self.start - relativeDeltaX / self.scale
        self.moveToPosition(relativeStart)
    }
}