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

enum AudioAnalizerState {
    case Idle
    case Reading
    case Finished
}

class DVGAudioAnalyzer: ChannelSource {
    
    let audioSource: DVGAudioSource_
    let asset: AVAsset
    var audioFormat = AudioStreamBasicDescription()
    var state = AudioAnalizerState.Idle
    var processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)
    
    var channelsCount: Int {
        return 1
    }
    
    private var scaleIndex = 0
    
    func channelAtIndex(index: Int) -> AbstractChannel {
        if index == 0 {
            return self.maxValueChannels[scaleIndex]
        } else {
            return self.avgValueChannels[scaleIndex]
        }
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

    func runAsynchronouslyOnProcessingQueue(block: dispatch_block_t) {
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
            let channel        = Channel<Int16>(logicProvider: AudioMaxValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(AudioMaxValueLogicProvider)
            maxValueChannels.append(channel)
        }
        self.maxValueChannels = maxValueChannels
        
        var avgValueChannels = [Channel<Float>]()
        for _ in 0..<channelPerLogicProviderType {
            let channel        = Channel<Float>(logicProvider: AudioAverageValueLogicProvider())
            channel.identifier = self.identifierForLogicProviderType(AudioAverageValueLogicProvider)
            avgValueChannels.append(channel)
        }
        self.avgValueChannels = avgValueChannels
    }

    func identifierForLogicProviderType(type: LogicProvider.Type) -> String {
        return "\(type.identifier).\(self.identifier)"
    }
    
    func read(count: Int, dataRange: DataRange = DataRange(), completion: () -> () = {}) {

        let scale      = 1.0 / dataRange.length
        var scaleIndex = (round(scale) == 1) ? 0 : Int(round(log2(scale)))
        scaleIndex     = min(9, scaleIndex)
        
        if scaleIndex == 0 && self.state == .Idle {
            
            let startTime      = kCMTimeZero
            let endTime        = self.asset.duration
            let audioTimeRange = CMTimeRange(start: startTime, end: endTime)
            
            let estimatedSampleCount = audioTimeRange.duration.seconds * self.audioFormat.mSampleRate
            let sampleBlockLength    = Int(estimatedSampleCount / Double(count))
            self.configureChannelsForBlockSize(sampleBlockLength, totalCount: count)
            self._read(count, completion: completion)
        } else {
             // change channel

            if scaleIndex != self.scaleIndex {
                print(scaleIndex)
                print(Int(round(log2(scale))))
                self.scaleIndex = scaleIndex
                self.onChannelsChanged(self)
            }
        }
    }
    
    func _read(count: Int, completion: () -> () = {}) {
        self.runAsynchronouslyOnProcessingQueue {
            [weak self] in
            if self == nil { return }
           
            self!.state = .Reading
            
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
                
                try self!.audioSource._readAudioSamplesData(sampleBlock: sampleBlock)
                
                for channel in self!.maxValueChannels {
                    channel.finalize()
                }
                
                for channel in self!.avgValueChannels {
                    channel.finalize()
                }
                
                completion()
                self!.state = .Finished
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
        }
    }
}
