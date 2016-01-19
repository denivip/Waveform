//
//  DVGAudioAnalyzer.swift
//  Denoise
//
//  Created by developer on 16/12/15.
//  Copyright © 2015 DENIVIP Group. All rights reserved.
//

import Foundation
import AVFoundation

private let kDVGNoiseFloor: Float = -40.0

struct DataRange {
    let location: Double
    let length: Double
    
    init(location: Double, length: Double) {
        assert(location >= 0.0)
        assert(length > 0.0)
        assert(location + length <= 1.0)
        
        self.location = location
        self.length   = length
    }
    
    init() {
        self.location = 0.0
        self.length   = 1.0
    }
}

class DVGAudioAnalyzer: ChannelSource {
    
    let audioSource: DVGAudioSource_
    let asset: AVAsset
    var audioFormat = AudioStreamBasicDescription()
    
    var processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)
    
    var channelsCount: Int {
        return 1
    }
    
    func channelAtIndex(index: Int) -> AbstractChannel {
//        if index == 0 {
//            return self.maxValueChannels[0]
//        } else {
            return self.avgValueChannels[0]
//        }
    }
    
    var onChannelsChanged: (ChannelSource) -> () = {_ in}
    var identifier       = "reader"

    var maxValueChannels = [Channel<Int16>]()
    var avgValueChannels = [Channel<Float>]()
    
    var channelPerLogicProviderType = 10

    //MARK:
    init(asset: AVAsset) {
        self.asset       = asset
        self.audioSource = DVGAudioSource_(asset: asset)
        self.configureChannels()
    }

    func runAsynchronouslyOnProcessingQueue(block: dispatch_block_t!) {
        if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(self.processingQueue)) {
            autoreleasepool(block)
        } else {
            dispatch_async(self.processingQueue, block);
        }
    }
    
    func prepareToRead(completion: (Bool) -> ()) {
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            
            if self == nil { return }
            
            self!.audioSource.readAudioFormat{ audioFormat, _ in

                if self == nil { return }

                guard let audioFormat = audioFormat else {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(false)
                    }
                    return
                }
                
                print(audioFormat)
                self!.audioFormat = audioFormat
                print(self!.audioFormat.mBitsPerChannel)
                dispatch_async(dispatch_get_main_queue()) {
                    completion(true)
                }
            }
        }
    }

    func configureChannelsForBlockSize(blockSize: Int, totalCount: Int) {
        for index in self.maxValueChannels.indices {
            let channel = self.maxValueChannels[index]
            channel.blockSize  = blockSize / Int(pow(2.0, Double(index)))
            channel.totalCount = totalCount * Int(pow(2.0, Double(index)))
        }

        for index in self.avgValueChannels.indices {
            let channel = self.avgValueChannels[index]
            channel.blockSize  = blockSize / Int(pow(2.0, Double(index)))
            channel.totalCount = totalCount * Int(pow(2.0, Double(index)))
        }
    }
    
    func configureChannels() {
        var maxValueChannels = [Channel<Int16>]()
        for _ in 0..<channelPerLogicProviderType {
            let channel        = Channel<Int16>(logicProvider: MaxValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(MaxValueLogicProvider)
            maxValueChannels.append(channel)
        }
        self.maxValueChannels = maxValueChannels
        
        var avgValueChannels = [Channel<Float>]()
        for _ in 0..<channelPerLogicProviderType {
            let channel        = Channel<Float>(logicProvider: AverageValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(AverageValueLogicProvider)
            avgValueChannels.append(channel)
        }
        self.avgValueChannels = avgValueChannels
    }

    
    func adjustedScaleFromScale(scale: Double) -> Int {
        switch scale {
        case 0..<1.5:
            return 1
        case 1.5..<3:
            return 2
        case 3..<6:
            return 4
        case 6..<12:
            return 8
        case 12..<24:
            return 16
        case 24..<48:
            return 32
        case 48..<96:
            return 64
        case 96..<192:
            return 128
        case 192..<394:
            return 256
        case 294..<798:
            return 512
        default:
            return 1
        }
    }
    
    func identifierForLogicProviderType(type: LogicProvider.Type) -> String {
        return "\(type.identifier).\(self.identifier)"
    }
    
    func read(count: Int, dataRange: DataRange = DataRange(), completion: () -> () = {}) {

        let scale         = 1.0 / dataRange.length
        let adjustedScale = self.adjustedScaleFromScale(scale)
        
        if adjustedScale == 1 {
            
            let startTime      = kCMTimeZero
            let endTime        = self.asset.duration
            let audioTimeRange = CMTimeRange(start: startTime, end: endTime)
            
            let estimatedSampleCount = audioTimeRange.duration.seconds * self.audioFormat.mSampleRate
            let sampleBlockLength    = Int(estimatedSampleCount / Double(count))
            self.configureChannelsForBlockSize(sampleBlockLength, totalCount: count)
            self._read(count, completion: completion)
            return
        }
        // change channel
        return
    }
    
    func _read(count: Int, completion: () -> () = {}) {
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            if self == nil { return }
            
            let channelsCount  = Int(self!.audioFormat.mChannelsPerFrame)

            do{
                let sampleBlock = { (dataSamples: UnsafePointer<Int16>!, length: Int) -> Bool in
                    
                    for index in 0..<self!.channelPerLogicProviderType {
                        let maxValueChannel = self!.maxValueChannels[index]
                        let avgValueChannel = self!.avgValueChannels[index]
                        for index in 0..<length {
                            let sample = dataSamples[channelsCount * index]
                            maxValueChannel.handleValue(NumberWrapper(sample))
                            avgValueChannel.handleValue(NumberWrapper(sample))
                        }
                    }
                    
                    return false
                }
                
                try self!.audioSource._readAudioSamplesData(sampleBlock: sampleBlock)
                
                for channel in self!.maxValueChannels {
                    channel.finalize()
                }
                
                for channel in self!.avgValueChannels {
                    channel.finalize()
                }
                
                completion()
                
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
        }
    }
}
