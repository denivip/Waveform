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

final
class DVGAudioAnalyzer {
    
    let audioSource: DVGAudioSource_
    let asset: AVAsset
    var audioFormat: AudioStreamBasicDescription!
    
    var processingQueue = dispatch_queue_create("ru.denivip.denoise.processing", DISPATCH_QUEUE_SERIAL)
    
    var neededPulsesCount = 0
    var currentBufferSize = 0
    
    var currentPulsesCount: Int { return self.currentBufferSize }
    var totalPulsesCount: Int   { return self.neededPulsesCount }
    
    var maxPulse = Int16(-40)
    
    private lazy var maxPulsesBuffer: UnsafeMutablePointer<Int16> = {
        return UnsafeMutablePointer<Int16>.alloc(self.neededPulsesCount)
    }()
    
    private lazy var avgPulsesBuffer: UnsafeMutablePointer<Int16>! = {
        return UnsafeMutablePointer<Int16>.alloc(self.neededPulsesCount)
    }()

    //TODO: Проверить происводительность с проверкой на выход за границы массива
    func maxPulseAtIndex(index: Int) -> Int16 {
        return self.maxPulsesBuffer[index]
    }
    func avgPulseAtIndex(index: Int) -> Int16 {
        return self.avgPulsesBuffer[index]
    }
    
    //MARK:
    init(asset: AVAsset) {
        self.asset       = asset
        self.audioSource = DVGAudioSource_(asset: asset)
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
            
            self!.audioSource.readAudioFormat{ success, _ in
                
                if !success {
                    dispatch_async(dispatch_get_main_queue()) {
                        completion(false)
                        return
                    }
                }
                
                self!.audioFormat = self!.audioSource.audioFormat
                dispatch_async(dispatch_get_main_queue()) {
                    completion(success)
                }
            }
        }
    }
    
    func readPCMs(neededPulsesCount neededPulsesCount: Int = 2208, completion: () -> () = {}) {
        self.neededPulsesCount = neededPulsesCount
        self.runAsynchronouslyOnProcessingQueue {
            let startTime      = kCMTimeZero
            let endTime        = self.asset.duration
            let audioTimeRange = CMTimeRange(start: startTime, end: endTime)
            let channelsCount  = Int(self.audioFormat.mChannelsPerFrame)

            let estimatedSampleCount = CMTimeGetSeconds(audioTimeRange.duration) * self.audioFormat.mSampleRate
            //???: Возможно нужно округлять sampleBlockLength в большую сторону (сейчас последний кусок данных меньший размера блока пропускается)
            let sampleBlockLength    = Int(estimatedSampleCount / Double(self.neededPulsesCount));
            
            print("sampleBlockLength = \(sampleBlockLength)")
            
            let avgSamplesDouble     = UnsafeMutablePointer<Double>.alloc(self.neededPulsesCount)
            let maxSamples           = UnsafeMutablePointer<Int16>.alloc(self.neededPulsesCount)
            
            for index in 0..<self.neededPulsesCount {
                avgSamplesDouble[index] = Double(kDVGNoiseFloor);
                maxSamples[index]       = Int16(kDVGNoiseFloor);
            }
            
            var maxAmplitude = Int16(kDVGNoiseFloor)
            var globalIndex  = 0
            var samplesCount = 0
            

            do{
                let sampleBlock = { (dataSamples: UnsafePointer<Int16>!, length: Int) -> Bool in
                    
                    var currentBlock = globalIndex / sampleBlockLength
                    
                    for index in 0..<length {
                        
                        if (currentBlock > self.neededPulsesCount){
                            break;
                        }
                        
                        let sample = dataSamples[channelsCount * index]
                        
                        let k = avgSamplesDouble[currentBlock]
                        avgSamplesDouble[currentBlock] = k + fabs(Double(sample) / Double(sampleBlockLength));
                        
                        if maxSamples[currentBlock] < sample {
                            maxSamples[currentBlock] = sample
                        }
                        
                        if (maxAmplitude < sample) {
                            maxAmplitude = sample
                            self.maxPulse = sample
                        }
                        
                        globalIndex = globalIndex + 1
                        let oldBlock = currentBlock
                        currentBlock = globalIndex / sampleBlockLength

                        if currentBlock > oldBlock {
                            self.avgPulsesBuffer[oldBlock] = Int16(avgSamplesDouble[oldBlock])
                            self.maxPulsesBuffer[oldBlock] = maxSamples[oldBlock]
                            self.currentBufferSize         = self.currentBufferSize + 1
                        }
//                        NSThread.sleepForTimeInterval(0.00001)
                    }

//                    print("globalIndex: \(globalIndex)")

                    samplesCount = samplesCount + length
                    
                    return false
                }
                
                try self.audioSource._readAudioSamplesData(sampleBlock: sampleBlock)
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
            avgSamplesDouble.destroy()
            avgSamplesDouble.dealloc(self.neededPulsesCount)
            
            maxSamples.destroy()
            maxSamples.dealloc(self.neededPulsesCount)
            
            self.neededPulsesCount = self.currentBufferSize
            completion()
        }
    }
    
}
