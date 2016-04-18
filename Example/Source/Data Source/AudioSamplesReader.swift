//
//  DVGAudioSource.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation
import AVFoundation

struct Constants {
    static var DefaultAudioFormat = AudioFormat.init(samplesRate: 44100, bitsDepth: 16, numberOfChannels: 2)
}

@objc final
class AudioSamplesReader: NSObject {
    
    var asset: AVAsset
    init(asset: AVAsset) {
        self.asset = asset
        super.init()
    }
        
    private var readingRoutine: SamplesReadingRoutine?
    
    weak var samplesHandler: AudioSamplesHandler?
    
    var nativeAudioFormat: AudioFormat?
    var samplesReadAudioFormat = Constants.DefaultAudioFormat
    
    var progress = NSProgress()
    
    func readAudioFormat(completionBlock: (AudioFormat?, SamplesReaderError?) -> ()) {
        dispatch_asynch_on_global_processing_queue {
            do {
                self.nativeAudioFormat = try self.readAudioFormat()
                completionBlock(self.nativeAudioFormat, nil)
                
            } catch let error as SamplesReaderError {
                
                completionBlock(nil, error)
                
            } catch let error {
                
                fatalError("unknown error:\(error)")
            }
        }
    }
    
    func readAudioFormat() throws -> AudioFormat {
        
        let formatDescription = try soundFormatDescription()
        
        print("DEBUG Audio format description => \(formatDescription)")
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription).memory
        let format = AudioFormat(samplesRate: Int(asbd.mSampleRate), bitsDepth: Int(asbd.mBitsPerChannel), numberOfChannels: Int(asbd.mChannelsPerFrame))
        nativeAudioFormat = format
        return format
    }
    
    func assetAudioTrack() throws -> AVAssetTrack {
        guard let sound = asset.tracksWithMediaType(AVMediaTypeAudio).first else {
            throw SamplesReaderError.NoSound
        }
        return sound
    }
    
    func soundFormatDescription() throws -> CMAudioFormatDescription {
        guard let formatDescription = try assetAudioTrack().formatDescriptions.first else {
            throw SamplesReaderError.InvalidAudioFormat
        }
        return formatDescription as! CMAudioFormatDescription
    }

    private func audioReadingSettingsForFormat(audioFormat: AudioFormat) -> [String: AnyObject] {
        return [
            AVFormatIDKey           : NSNumber(unsignedInt: kAudioFormatLinearPCM),
            AVSampleRateKey         : audioFormat.samplesRate,
            AVNumberOfChannelsKey   : audioFormat.numberOfChannels,
            AVLinearPCMBitDepthKey  : audioFormat.bitsDepth > 0 ? audioFormat.bitsDepth : 16,
            AVLinearPCMIsBigEndianKey   : false,
            AVLinearPCMIsFloatKey       : false,
            AVLinearPCMIsNonInterleaved : false
        ]
    }

    func readSamples(audioFormat: AudioFormat? = nil, completion: (ErrorType?) -> ()) {
        dispatch_asynch_on_global_processing_queue({
            try self.readSamples(audioFormat) }, onCatch: completion)
    }
    
    func readSamples(audioFormat: AudioFormat? = nil) throws {
        if let format = audioFormat {
            samplesReadAudioFormat = format
        }
        try self.prepareForReading()
        try self.read()
    }

    private func prepareForReading() throws {
        
        let sound = try assetAudioTrack()
        
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch let error as NSError {
            throw SamplesReaderError.UnknownError(error)
        }
    
        let settings = audioReadingSettingsForFormat(samplesReadAudioFormat)
        
        let readerOutput = AVAssetReaderTrackOutput(track: sound, outputSettings: settings)
        
        assetReader.addOutput(readerOutput)
        assetReader.timeRange = CMTimeRange(start: kCMTimeZero, duration: asset.duration)
        
        if samplesHandler == nil {
            print("\(#function)[\(#line)] Caution!!! There is no samples handler")
        }

        self.readingRoutine = SamplesReadingRoutine(assetReader: assetReader, readerOutput: readerOutput, audioFormat: samplesReadAudioFormat, samplesHandler: samplesHandler, progress: self.progress)
    }
    
    private func read() throws {
        
        guard let readingRoutine = readingRoutine else {
            throw SamplesReaderError.SampleReaderNotReady
        }
        try readingRoutine.readSamples()
    }
}

final class SamplesReadingRoutine {
    
    let assetReader: AVAssetReader
    let readerOutput: AVAssetReaderOutput
    let audioFormat: AudioFormat
    weak var samplesHandler: AudioSamplesHandler?

    let progress: NSProgress

    lazy var estimatedSamplesCount: Int = {
        return Int(self.assetReader.asset.duration.seconds * Double(self.audioFormat.samplesRate))
    }()
    
    init(assetReader: AVAssetReader, readerOutput: AVAssetReaderOutput, audioFormat: AudioFormat, samplesHandler: AudioSamplesHandler?, progress: NSProgress) {
        self.assetReader  = assetReader
        self.readerOutput = readerOutput
        self.audioFormat  = audioFormat
        self.samplesHandler = samplesHandler
        self.progress = progress
        progress.totalUnitCount = Int64(self.estimatedSamplesCount)
    }
    
    var isReading: Bool {
        return assetReader.status == .Reading
    }
    
    func startReading() throws  {
        if !assetReader.startReading() {
            throw SamplesReaderError.CantReadSamples(assetReader.error)
        }
    }

    func cancelReading() {
        assetReader.cancelReading()
    }
    
    func readSamples() throws {
        self.samplesHandler?.willStartReadSamples(estimatedSampleCount: estimatedSamplesCount)
        try startReading()
        while isReading {
            do {
                try readNextSamples()
            } catch (_ as NoMoreSampleBuffersAvailable) {
                break
            } catch {
                cancelReading()
                throw error
            }
        }
        try checkStatusOfAssetReaderOnComplete()
        self.samplesHandler?.didStopReadSamples(Int(self.progress.completedUnitCount))
    }
    
    func readNextSamples() throws {
        guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
            throw NoMoreSampleBuffersAvailable()
        }
        
        // Get buffer
        guard let buffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            throw SamplesReaderError.UnknownError(nil)
        }
        
        let length = CMBlockBufferGetDataLength(buffer)
        
        // Append new data
        let tempBytes = UnsafeMutablePointer<Void>.alloc(length)
        var returnedPointer: UnsafeMutablePointer<Int8> = nil
    
        if CMBlockBufferAccessDataBytes(buffer, 0, length, tempBytes, &returnedPointer) != kCMBlockBufferNoErr {
            throw NoEnoughData()
        }
        
        tempBytes.destroy(length)
        tempBytes.dealloc(length)
    
        let samplesContainer = AudioSamplesContainer(buffer: returnedPointer, length: length, numberOfChannels: audioFormat.numberOfChannels)
        samplesHandler?.handleSamples(samplesContainer)
        progress.completedUnitCount += samplesContainer.samplesCount
    }
    
    func checkStatusOfAssetReaderOnComplete() throws {
        switch assetReader.status {
        case .Unknown, .Failed, .Reading:
            throw SamplesReaderError.UnknownError(assetReader.error)
        case .Cancelled, .Completed:
            return
        }
    }
}
