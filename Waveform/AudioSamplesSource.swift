//
//  DVGAudioAnalyzer.swift
//  Denoise
//
//  Created by developer on 16/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

import Foundation
import AVFoundation

class AudioSamplesSource: NSObject, ChannelSource {

    //MARK: - Initialization
    convenience init(asset: AVAsset) {
        self.init()
        self.asset       = asset
        self.audioSource = DVGAudioSource_(asset: asset)
    }
    
    override init() {
        super.init()
        self.createChannelsForDefaultLogicTypes()
    }
    
    //MARK: -
    //MARK: - Inner configuration
    func configureChannelsForSamplesCount(samplesCount: Int, timeRange: CMTimeRange) {
        
        let estimatedSampleCount = timeRange.duration.seconds * self.audioFormat.mSampleRate
        
        for index in self.maxValueChannels.indices {
            let channel = self.maxValueChannels[index]
            channel.totalCount = Int(Double(samplesCount) * pow(2.0, Double(index)))
            channel.blockSize  = Int(ceil(estimatedSampleCount/Double(channel.totalCount)))
        }
        
        for index in self.avgValueChannels.indices {
            let channel = self.avgValueChannels[index]
            channel.totalCount = Int(Double(samplesCount) * pow(2.0, Double(index)))
            channel.blockSize  = Int(ceil(estimatedSampleCount/Double(channel.totalCount)))
        }
    }
    
    func createChannelsForDefaultLogicTypes() {
        
        var maxValueChannels = [Channel<Int16>]()
        
        for _ in 0..<channelPerLogicProviderType {
            let channel        = Channel<Int16>(logicProvider: AudioMaxValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(AudioMaxValueLogicProvider)
            maxValueChannels.append(channel)
        }
        
        self.maxValueChannels = maxValueChannels
        //???: Is there any reason to store Float?
        var avgValueChannels = [Channel<Float>]()
        
        for _ in 0..<channelPerLogicProviderType {
            let channel        = Channel<Float>(logicProvider: AudioAverageValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(AudioAverageValueLogicProvider)
            avgValueChannels.append(channel)
        }
        self.avgValueChannels = avgValueChannels
    }

    func identifierForLogicProviderType(type: LogicProvider.Type) -> String {
        return self.identifier + "." + type.typeIdentifier
    }
    
    //MARK: - Reading
    //TODO: There's no need in such public methods (combine with read method)
    func prepareToRead(completion: (Bool) -> ()) {
        
        assert(self.audioSource != nil, "No audio source")
        
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            
            if self == nil { return }
            
            self?.audioSource?.readAudioFormat{ audioFormat, _ in

                if self == nil { return }

                guard let audioFormat = audioFormat else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(false)
                    }
                    return
                }
                
                self!.audioFormat = audioFormat
                dispatch_async(dispatch_get_main_queue()) {
                    completion(true)
                }
            }
        }
    }

    //TODO: Method should return NSProgress, to trace it outside
    func read(count: Int, dataRange: DataRange = DataRange(), completion: () -> () = {}) {

        assert(self.asset != nil, "No asset")
        
        let scale      = 1.0 / dataRange.length
        var scaleIndex = Int(floor(log2(scale)))
        scaleIndex     = min(self.channelPerLogicProviderType - 1, scaleIndex)
        
        if scaleIndex == 0 && self.state == .Idle {
            
            let startTime      = kCMTimeZero
            let endTime        = self.asset!.duration
            let audioTimeRange = CMTimeRange(start: startTime, end: endTime)
        
            self.configureChannelsForSamplesCount(count, timeRange: audioTimeRange)
            self._read(count, completion: completion)
        } else {
             // change channel

            if scaleIndex != self.scaleIndex {
                self.scaleIndex = scaleIndex
                self.onChannelsChanged(self)
            }
        }
    }
    
    func _read(count: Int, completion: () -> () = {}) {
        
        assert(self.audioSource != nil, "No audio source")
        
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            if self == nil { return }
           
            self?.state = .Reading
            
            let channelsCount  = Int(self!.audioFormat.mChannelsPerFrame)

            do{
                let sampleBlock = { (dataSamples: UnsafePointer<Int16>!, length: Int) -> Bool in
                    
                    for index in 0..<self!.channelPerLogicProviderType {
                        let maxValueChannel = self!.maxValueChannels[index]
                        let avgValueChannel = self!.avgValueChannels[index]
                        for index in 0..<length {
                            let sample = dataSamples[channelsCount * index]
                            maxValueChannel.handleValue(Double(sample))
                            avgValueChannel.handleValue(Double(sample))
                        }
                    }
                    
                    return false
                }
                
                try self?.audioSource?._readAudioSamplesData(sampleBlock: sampleBlock)
                
                for channel in self!.maxValueChannels {
                    channel.complete()
                }
                
                for channel in self!.avgValueChannels {
                    channel.complete()
                }
                
                completion()
                self!.state = .Finished
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
        }
    }
    
    //MARK: -
    //MARK: - Private Variables
    var audioSource: DVGAudioSource_?
    var audioFormat = AudioStreamBasicDescription()
    var processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)
    var maxValueChannels = [Channel<Int16>]()
    var avgValueChannels = [Channel<Float>]()
    
    private var scaleIndex = 0
    
    //MARK: - Public Variables
    var asset: AVAsset? {
        didSet{
            if let asset = self.asset {
                self.audioSource = DVGAudioSource_(asset: asset)
            }
        }
    }
    
    var state = AudioAnalizerState.Idle
    var channelPerLogicProviderType = 10
    @objc var onChannelsChanged: (ChannelSource) -> () = {_ in}
//}
//
////MARK: -
////MARK: - ChannelSource
//extension AudioSamplesSource: ChannelSource {
    @objc var channelsCount: Int {
        return 2
    }
    
    @objc func channelAtIndex(index: Int) -> AbstractChannel {
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
    
    init(var location: Double, length: Double) {
        assert(location >= 0.0)
        assert(length > 0.0)
        assert(length <= 1.0)
        location = min(location, 1 - length)
        
        self.location = location
        self.length   = length
    }
    
    init() {
        self.location = 0.0
        self.length   = 1.0
    }
}

extension AudioSamplesSource {
    enum AudioAnalizerState {
        case Idle
        case Reading
        case Finished
    }
    func runAsynchronouslyOnProcessingQueue(block: dispatch_block_t) {
        if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(self.processingQueue)) {
            autoreleasepool(block)
        } else {
            dispatch_async(self.processingQueue, block);
        }
    }
}

