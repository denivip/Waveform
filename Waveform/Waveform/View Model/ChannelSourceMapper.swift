//
//  DataSourceMapper.swift
//  Waveform
//
//  Created by qqqqq on 17/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

class ChannelSourceMapper: ChannelSource {

    var channelSources: [ChannelSource] = []
    func addChannelSource(channelSource: ChannelSource) {
        channelSources.append(channelSource)
        channelSource.onChannelsChanged = { [weak self] in self?.onChannelsChanged() }
    }
    
    var channelsCount: Int {
        return channelSources.reduce(0) { $0.0 + $0.1.channelsCount }
    }
    
    var onChannelsChanged: () -> () = {_ in}
    func channelAtIndex(index: Int) -> Channel {
        var tmpIndex = index
        for channelSource in channelSources {
            if tmpIndex < channelSource.channelsCount {
                return channelSource.channelAtIndex(tmpIndex)
            }
            tmpIndex -= channelSource.channelsCount
        }
        fatalError()
    }
}