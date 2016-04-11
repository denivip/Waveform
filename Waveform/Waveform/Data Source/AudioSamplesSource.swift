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
        self.audioSource = AudioSamplesReader(asset: asset)
    }
    
    override init() {
        super.init()
        self.createChannelsForDefaultLogicTypes()
    }
    
    //MARK: -
    //MARK: - Inner configuration
    func configureChannelsForSamplesCount(samplesCount: Int, timeRange: CMTimeRange) {
        
        let estimatedSampleCount = timeRange.duration.seconds * Double(self.audioFormat.samplesRate)
        print("estimatedSampleCount ", estimatedSampleCount)
        
        for index in self.maxValueChannels.indices {
            let channel = self.maxValueChannels[index]
            let totalCount = Int(Double(samplesCount) * pow(2.0, Double(index)))
            let blockSize  = Int(ceil(estimatedSampleCount/Double(totalCount)))
            
            channel.totalCount = Int(estimatedSampleCount/Double(blockSize))
            channel.blockSize  = blockSize
        }
        
        for index in self.avgValueChannels.indices {
            let channel = self.avgValueChannels[index]
            
            let totalCount = Int(Double(samplesCount) * pow(2.0, Double(index)))
            let blockSize  = Int(ceil(estimatedSampleCount/Double(totalCount)))
            
            channel.totalCount = Int(estimatedSampleCount/Double(blockSize))
            channel.blockSize  = blockSize
            print(channel.blockSize, channel.totalCount)
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
            guard let strong_self = self else { return }

            strong_self.audioSource.readAudioFormat{ audioFormat, _ in

                guard let strong_self = self else { return }

                guard let audioFormat = audioFormat else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(false)
                    }
                    return
                }
                
//                strong_self.audioFormat = audioFormat
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
    
    var shouldStop = false

    func _read(count: Int, completion: () -> () = {}) {
        
        assert(self.audioSource != nil, "No audio source")
        
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            
            guard let strong_self = self else { return }
           
            strong_self.state = .Reading
            
            let channelIndex  = 0
            
            let samplesHandlingBlock = { [weak self] (samplesContainer: AudioSamplesContainer<Int16>) in
                
                for index in 0..<strong_self.channelPerLogicProviderType {
                    let maxValueChannel = strong_self.maxValueChannels[index]
                    let avgValueChannel = strong_self.avgValueChannels[index]
                    for index in 0..<samplesContainer.samplesCount {
                        let sample = samplesContainer.sample(sampleIndex: index)//dataSamples[index * numberOfChannels + channelIndex]
                        maxValueChannel.handleValue(Double(sample))
                        avgValueChannel.handleValue(Double(sample))
                    }
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    let maxValueChannel = strong_self.maxValueChannels[0]
                    strong_self.progress.completedUnitCount = strong_self.progress.totalUnitCount * Int64(maxValueChannel.count) / Int64(maxValueChannel.totalCount)
                })
                
                if self == nil || self!.shouldStop {
                    self!.audioSource.stop()
                }
            }
            
            do {
                
                try strong_self.audioSource?.readSamples(samplesHandlingBlock: samplesHandlingBlock)
                
                for channel in strong_self.maxValueChannels {
                    channel.complete()
                }
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    strong_self.progress.completedUnitCount = strong_self.progress.totalUnitCount
                })
                
                for channel in strong_self.avgValueChannels {
                    channel.complete()
                }
                
                completion()
                strong_self.state = .Finished
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
        }
    }
    
    //MARK: -
    //MARK: - Private Variables
    var audioSource: AudioSamplesReader!
    var audioFormat = Constants.DefaultAudioFormat//AudioFormat(samplesRate: 0, bitsDepth: 0, numberOfChannels: 0)
    var processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)
    var maxValueChannels = [Channel<Int16>]()
    var avgValueChannels = [Channel<Float>]()
    
    private var scaleIndex = 0
    
    //MARK: - Public Variables
    var asset: AVAsset? {
        didSet{
            if let asset = self.asset {
                self.audioSource = AudioSamplesReader(asset: asset)
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
    
    lazy var progress: NSProgress = {
        let progress = NSProgress(parent: nil, userInfo: nil)
        progress.totalUnitCount = 10_000
        return progress
    }()
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

