//
//  DiagramModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation
import UIKit.UIColor

class DiagramModel: NSObject, DiagramDataSource {
    
    weak var channelsSource: ChannelSource? {
        didSet{
            guard let channelsSource = channelsSource else {
                return
            }
            channelsSource.onChannelsChanged = {
                [weak self, weak channelsSource] in
                if let channelsSource = channelsSource {
                    self?.resetChannelsFromDataSources(channelsSource)
                }
            }
            self.resetChannelsFromDataSources(channelsSource)
        }
    }
    weak var delegate: DiagramViewModelDelegate?
    
    private var viewModels = [PlotModel]()
    
    var scale: CGFloat = 1.0
    var start: CGFloat = 0.0
    var onPlotUpdate: () -> () = {}

    var plotDataSourcesCount: Int { return self.viewModels.count }
    func plotDataSourceAtIndex(index: Int) -> PlotDataSource {
        return self.viewModels[index]
    }
    
    func resetChannelsFromDataSources(channelsSource: ChannelSource) {
        self.adjustViewModelsCountWithCount(channelsSource.channelsCount)
        for index in 0..<channelsSource.channelsCount {
            let channel = channelsSource.channelAtIndex(index)
            let viewModel = self.viewModels[index]
            viewModel.plotModel = self
            viewModel.channel = channel
        }
    }
    
    func adjustViewModelsCountWithCount(count: Int) {
        if viewModels.count == count {
            return
        }
        if viewModels.count < count {
            for _ in viewModels.count..<count {
                viewModels.append(PlotModel())
            }
            return
        }
        if viewModels.count > count {
            for _ in count..<viewModels.count {
                viewModels.removeLast()
            }
        }
    }
    
    func viewModelWithIdentifier(identifier: String) -> PlotModel? {
        for viewModel in self.viewModels {
            if viewModel.identifier == identifier {
                return viewModel
            }
        }
        return nil
    }

    func maxBounds() -> CGSize {
        var maxHeight: CGFloat = 0.1
        guard let channelsSource = channelsSource else {
            return .zero
        }
        for index in 0..<channelsSource.channelsCount {
            let channel = channelsSource.channelAtIndex(index)
            if CGFloat(channel.maxValue) > maxHeight {
                maxHeight = CGFloat(channel.maxValue)
            }
        }
        return CGSize(width: 1.0, height: maxHeight)
    }
    
    func absoluteRangeFromRelativeRange(range: DataRange) -> DataRange {
        return DataRange(location: Double(self.start) + range.location/Double(self.scale), length: range.length/Double(self.scale))
    }
}

extension DiagramModel: DiagramDelegate {
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