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
class ScalableChannelsContainer: NSObject, AbstractChannelSource, AudioSamplesHandler {
    
    override init() {
        super.init()
        self.createChannelsForDefaultLogicTypes()
    }
    
    //MARK: -
    //MARK: - Inner configuration
    func configureChannelsForSamplesCount(samplesCount: Int, estimatedSampleCount: Int) {
        
        print("estimatedSampleCount ", estimatedSampleCount)
        
        for index in self.maxValueChannels.indices {
            let channel = self.maxValueChannels[index]
            let totalCount = Int(Double(samplesCount) * pow(Double(scaleInterLevelFactor), Double(index)))
            let blockSize  = Int(ceil(Double(estimatedSampleCount)/Double(totalCount)))
            
            channel.totalCount = Int(Double(estimatedSampleCount)/Double(blockSize))
            channel.blockSize  = blockSize
        }
        
        for index in self.avgValueChannels.indices {
            let channel = self.avgValueChannels[index]
            
            let totalCount = Int(Double(samplesCount) * pow(Double(scaleInterLevelFactor), Double(index)))
            let blockSize  = Int(ceil(Double(estimatedSampleCount)/Double(totalCount)))
            
            channel.totalCount = Int(Double(estimatedSampleCount)/Double(blockSize))
            channel.blockSize  = blockSize
            print(channel.blockSize, channel.totalCount)
        }
    }
    
    func createChannelsForDefaultLogicTypes() {
        
        var maxValueChannels = [Channel]()
        
        for _ in 0..<numberOfScaleLevels {
            let channel        = Channel(logicProvider: AudioMaxValueLogicProvider(), buffer: GenericBuffer<Int16>())
            channel.identifier = self.identifier + "." + channel.identifier
            maxValueChannels.append(channel)
        }
        
        self.maxValueChannels = maxValueChannels
        //???: Is there any reason to store Float?
        var avgValueChannels = [Channel]()
        
        for _ in 0..<numberOfScaleLevels {
            let channel        = Channel(logicProvider: AudioAverageValueLogicProvider(), buffer: GenericBuffer<Float>())
            channel.identifier = self.identifier + "." + channel.identifier
            avgValueChannels.append(channel)
        }
        self.avgValueChannels = avgValueChannels
    }
    
    //TODO: - Rename
    func configure(estimatedSampleCount estimatedSampleCount: Int, neededSamplesCount: Int) {
        self.configureChannelsForSamplesCount(neededSamplesCount, estimatedSampleCount: estimatedSampleCount)
    }
    
    func configure(dataRange: DataRange) {
        assert(self.avgValueChannels.count > 0, "you should configure channels first. see method above")
        
        let scale      = 1.0 / dataRange.length
        var scaleIndex = Int(floor(log(scale)/log(Double(scaleInterLevelFactor))))
        scaleIndex     = min(self.numberOfScaleLevels - 1, scaleIndex)
        if scaleIndex != self.scaleIndex {
            self.scaleIndex = scaleIndex
            self.onChannelsChanged(self)
        }
    }
    
    func willStartReadSamples(estimatedSampleCount estimatedSampleCount: Int) {
        configure(estimatedSampleCount: estimatedSampleCount, neededSamplesCount: neededSamplesCount)
    }
    
    func didStopReadSamples(count: Int) {
        for channel in self.maxValueChannels {
            channel.complete()
        }
        for channel in self.avgValueChannels {
            channel.complete()
        }
    }
        
    func handleSamples(samplesContainer: AudioSamplesContainer) {

        for channelIndex in 0..<self.numberOfScaleLevels {
            let maxValueChannel = self.maxValueChannels[channelIndex]
            let avgValueChannel = self.avgValueChannels[channelIndex]
           
            for sampleIndex in 0..<samplesContainer.samplesCount {
                let sample = samplesContainer.sample(channelIndex: 0, sampleIndex: sampleIndex)
                maxValueChannel.handleValue(sample)
                avgValueChannel.handleValue(sample)
            }
        }
    }
    
    //MARK: -
    //MARK: - Private Variables
    internal var identifier = "SourceAudioSamples"
    var numberOfScaleLevels: Int = 5
    var scaleInterLevelFactor: Int = 4
    var neededSamplesCount: Int = Int(300 * 1.5 * 4/2)
    
    var scaleIndex = 0
    private var maxValueChannels = [Channel]()
    private var avgValueChannels = [Channel]()
    
    var onChannelsChanged: (AbstractChannelSource) -> () = {_ in}
//}
//
////MARK: -
////MARK: - ChannelSource
//extension AudioSamplesSource: ChannelSource {
    var channelsCount: Int {
        return 2
    }
    
    func channelAtIndex(index: Int) -> Channel {
        if index == 0 {
            return self.maxValueChannels[scaleIndex]
        } else {
            return self.avgValueChannels[scaleIndex]
        }
    }
}

//MARK: -
//MARK: - Utility
struct DataRange {
    let location: Double
    let length: Double
    
    init(location: Double, length: Double) {
        assert(location >= 0.0)
        assert(length > 0.0)
        assert(length <= 1.0)
        let location = min(location, 1 - length)
        
        self.location = location
        self.length   = length
    }

    init(location: CGFloat, length: CGFloat) {
        let _location = Double(location)
        let _length   = Double(length)
        self = DataRange(location: _location, length: _length)
    }
    
    init() {
        self.location = 0.0
        self.length   = 1.0
    }
}
