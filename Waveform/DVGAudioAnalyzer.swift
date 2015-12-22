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
class DVGAudioAnalyzer: NSObject {
    
    let audioSource: DVGAudioSource!
    let asset: AVAsset!
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
        self.audioSource = DVGAudioSource(asset: asset)
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
                let sampleBlock = { (data: NSData!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    
                    let dataSamplesCount = data.length / sizeof(Int16) / channelsCount
                    let dataSamples      = UnsafePointer<Int16>(data.bytes);
                    
                    var currentBlock = globalIndex / sampleBlockLength
                    
                    for index in 0..<dataSamplesCount {
                        
                        if (currentBlock > self.neededPulsesCount){
                            continue;
                        }
                        
                        let sample = dataSamples[channelsCount * index]
                        
                        avgSamplesDouble[currentBlock] += fabs(Double(sample) / Double(sampleBlockLength));
                        
                        if maxSamples[currentBlock] < sample {
                            maxSamples[currentBlock] = sample
                        }
                        
                        if (maxAmplitude < sample) {
                            maxAmplitude = sample
                            self.maxPulse = sample
                        }
                        
                        globalIndex++
                        let oldBlock = currentBlock
                        currentBlock = globalIndex / sampleBlockLength

                        if currentBlock > oldBlock {
                            self.avgPulsesBuffer[oldBlock] = Int16(avgSamplesDouble[oldBlock])
                            self.maxPulsesBuffer[oldBlock] = maxSamples[oldBlock]
                            self.currentBufferSize++
                        }
//                        NSThread.sleepForTimeInterval(0.00005)
                    }
                    
                    samplesCount += dataSamplesCount
                }
                
                try self.audioSource.readAudioSamplesIntervalData(sampleBlock, timerange: audioTimeRange)
            } catch {
                print("\(__FUNCTION__) \(__LINE__), \(error)")
            }
            completion()
        }
    }
    
    func readFullAggregateWaveformDataWithSampleCount(aggregateSampleCount_: UInt, outAverage avgSamplesDataOut: NSMutableData!, outMaximum maxSamplesDataOut: NSMutableData!, maxAmplitude maxAmplitudeOut: UnsafeMutablePointer<Int16>) {
    
        let aggregateSampleCount = Int(aggregateSampleCount_)
        let startTime = kCMTimeZero
        let endTime   = self.asset.duration
        let audioTimeRange = CMTimeRangeMake(startTime, CMTimeSubtract(endTime, startTime))
        print(String("startTime=%@.1f <=> endTime=%@.1f",CMTimeGetSeconds(startTime), CMTimeGetSeconds(endTime)))
        
        let channelsCount = Int(self.audioFormat.mChannelsPerFrame)
        // Samples in one channel
        let estimatedSampleCount = CMTimeGetSeconds(audioTimeRange.duration) * self.audioFormat.mSampleRate

//        let progress = DVGProgress.__discreteProgressWithTotalUnitCount(Int64(estimatedSampleCount * 1.1))
//        progress.userDescription = NSLocalizedString("Loading sound", comment: "")
        print("estimatedSampleCount = \(estimatedSampleCount)")

        // How many original samples per one aggregated
        let sampleBlockLength = Int(estimatedSampleCount / Double(aggregateSampleCount));
        print("sampleBlockLength = \(sampleBlockLength), aggregateSampleCount = \(aggregateSampleCount)")
    
        self.runAsynchronouslyOnProcessingQueue{
            [weak self] in
            if self == nil { return }
            
            let avgSamplesDoubleData = NSMutableData(length: Int(aggregateSampleCount) * sizeof(Double))!
            let avgSamplesDouble     = UnsafeMutablePointer<Double>(avgSamplesDoubleData.mutableBytes)

            // Initialize maximum samples data
            let maxSamplesData = NSMutableData(length: Int(aggregateSampleCount) * sizeof(Int16))!
            let maxSamples     = UnsafeMutablePointer<Int16>(maxSamplesData.mutableBytes)
            
            for index in 0..<Int(aggregateSampleCount) {
                avgSamplesDouble[index] = Double(kDVGNoiseFloor);
                maxSamples[index]       = Int16(kDVGNoiseFloor);
            }
            
            var maxAmplitude = Int16(kDVGNoiseFloor)
            var globalIndex  = 0
            var samplesCount = 0
            
            do{
                let sampleBlock = { (data: NSData!, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                    
                    let dataSamplesCount = data.length / sizeof(Int16) / channelsCount
                    let dataSamples = UnsafeMutablePointer<Int16>(data.bytes);
                    
                    for index in 0..<dataSamplesCount {
                        
                        let block = globalIndex / sampleBlockLength
                        
                        if (block > aggregateSampleCount){
                            continue;
                        }
                        
                        var sample = dataSamples[channelsCount * index]
                        
                        avgSamplesDouble[block] += fabs(Double(sample) / Double(sampleBlockLength));
                        
                        if maxSamples[block] < sample {
                            maxSamples[block] = sample
                        }
                        
                        if (maxAmplitude < sample) {
                            maxAmplitude = sample
                            maxAmplitudeOut.memory = sample
                        }
                        
                        sample = UnsafeMutablePointer<Int16>(avgSamplesDouble)[block]

                        var asdoValue = Int16(avgSamplesDouble[block])
                        avgSamplesDataOut.replaceBytesInRange(NSMakeRange(block * sizeof(Int16), sizeof(Int16)), withBytes: &asdoValue)
                        
                        var msdoValue = maxSamples[block]
                        maxSamplesDataOut.replaceBytesInRange(NSMakeRange(block * sizeof(Int16), sizeof(Int16)), withBytes: &msdoValue)
                        
                        globalIndex++
                    }
                    
                    samplesCount += dataSamplesCount
//                    progress.completedUnitCount = Int64(samplesCount)
          
//                    if (progress.cancelled){
//                        stop.memory = true
//                    }
                }

                try self!.audioSource.readAudioSamplesIntervalData(sampleBlock, timerange: audioTimeRange)
            } catch let error {
                print("\(__FUNCTION__) \(__LINE__) error: \(error)")
                samplesCount = 0
            }
            
            if maxAmplitude == 0 {
                samplesCount = 0
            }
            
//            progress.liveContext[kDVGTotalSamplesKey] = samplesCount
            
            if samplesCount == 0 {
//                let error = NSError(domain: "ErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("Error reading audio data", comment:"")])
//                progress.completeWithError(error)
                return
            }
            
//            self!.samplesCount = samplesCount * channelsCount
//            progress.completeWithError(nil)
        }
        return
//        return progress
    }
}
