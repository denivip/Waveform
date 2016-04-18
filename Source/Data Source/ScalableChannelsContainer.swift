//
//  DVGAudioAnalyzer.swift
//  Denoise
//
//  Created by developer on 16/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

import Foundation
import AVFoundation

@objc
final
class ScalableChannelsContainer: NSObject, ChannelSource, AudioSamplesHandler {
    
    override init() {
        super.init()
        self.createChannelsForDefaultLogicTypes()
    }
    
    //MARK: -
    //MARK: - Inner configuration
    func configure(neededSamplesCount neededSamplesCount: Int, estimatedSampleCount: Int) {
        
        print("estimatedSampleCount ", estimatedSampleCount)
        
        for index in 0..<numberOfScaleLevels {
            
            var totalCount = Int(Double(neededSamplesCount) * pow(Double(scaleInterLevelFactor), Double(index)))
            let blockSize  = Int(ceil(Double(estimatedSampleCount)/Double(totalCount)))
            totalCount = Int(Double(estimatedSampleCount)/Double(blockSize))

            let channel = channels[index * channelsCount]
            let channel_ = channels[index * channelsCount + 1]
            
            channel.totalCount = totalCount
            channel.blockSize  = blockSize
            
            channel_.totalCount = totalCount
            channel_.blockSize  = blockSize
            print(channel_.blockSize, channel_.totalCount)
        }
    }
    
    func createChannelsForDefaultLogicTypes() {
        
        var channels = [Channel]()
        
        for _ in 0..<numberOfScaleLevels {
            let channel        = Channel(logicProvider: AudioMaxValueLogicProvider(), buffer: GenericBuffer<Int16>())
            channel.identifier = self.identifier + "." + channel.identifier
            channels.append(channel)
        
            //???: Is there any reason to store Float?
            let channel_        = Channel(logicProvider: AudioAverageValueLogicProvider(), buffer: GenericBuffer<Float>())
            channel_.identifier = self.identifier + "." + channel_.identifier
            channels.append(channel_)
        }
        
        self.channels = channels
    }
    
    
    func reset(dataRange: DataRange) {
        assert(self.channels.count > 0, "you should configure channels first. see method above")
        
        let scale      = 1.0 / dataRange.length
        var scaleIndex = Int(floor(log(scale)/log(Double(scaleInterLevelFactor))))
        scaleIndex     = min(self.numberOfScaleLevels - 1, scaleIndex)
        if scaleIndex != self.scaleIndex {
            self.scaleIndex = scaleIndex
            self.onChannelsChanged()
        }
    }
    
    func willStartReadSamples(estimatedSampleCount estimatedSampleCount: Int) {
        configure(neededSamplesCount: neededSamplesCount, estimatedSampleCount: estimatedSampleCount)
    }
    
    func didStopReadSamples(count: Int) {
        for channel in channels {
            channel.complete()
        }
    }
        
    func handleSamples(samplesContainer: AudioSamplesContainer) {

        for channelIndex in 0..<numberOfScaleLevels {
            
            let channel = channels[channelIndex * channelsCount]
            let channel_ = channels[channelIndex * channelsCount + 1]
            
            for sampleIndex in 0..<samplesContainer.samplesCount {
                let sample = samplesContainer.sample(channelIndex: 0, sampleIndex: sampleIndex)
                channel.handleValue(sample)
                channel_.handleValue(sample)
            }
        }
    }
    
    //MARK: -
    //MARK: - Private Variables
    struct Defaults {
        static var identifier            = "SourceAudioSamples"
        static var numberOfScaleLevels   = 10
        static var scaleInterLevelFactor = 2
        static var neededSamplesCount    = 500
    }
    var identifier            = Defaults.identifier
    var numberOfScaleLevels   = Defaults.numberOfScaleLevels
    var scaleInterLevelFactor = Defaults.scaleInterLevelFactor
    var neededSamplesCount    = Defaults.neededSamplesCount
    
    var scaleIndex = 0
    private var channels = [Channel]()
    
    
    var onChannelsChanged: () -> () = {_ in}

    var channelsCount: Int = 2
    
    func channelAtIndex(index: Int) -> Channel {
        return channels[index + scaleIndex * channelsCount]
    }
}

//MARK: -
//MARK: - Utility
struct DataRange {
    let location: Double
    let length: Double
    
    init(location: Double, length: Double) {        
        self.location = location
        self.length   = length
    }

    init(location: CGFloat, length: CGFloat) {
        self.location = Double(location)
        self.length   = Double(length)
    }
    
    init() {
        self.location = 0.0
        self.length   = 1.0
    }
}
