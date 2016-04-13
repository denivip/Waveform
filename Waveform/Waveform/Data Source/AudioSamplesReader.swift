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
    }
    
    private var readingRoutine: SamplesReadingRoutine?
    
    weak var samplesHandler: AudioSamplesHandler?
    
    var shouldStop = false
    
    func stop() {
        shouldStop = true
    }
    
    var nativeAudioFormat: AudioFormat?
    var samplesReadAudioFormat = Constants.DefaultAudioFormat
    
    func readAudioFormat(completionBlock: (AudioFormat?, SamplesReaderError?) -> ()) {
        
        do {
            self.nativeAudioFormat = try self.readAudioFormat()
            completionBlock(nativeAudioFormat, nil)
            
        } catch let error as SamplesReaderError {
            
            completionBlock(nil, error)
        
        } catch let error {

            fatalError("unknown error:\(error)")
        }
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

    func readAudioFormat() throws -> AudioFormat {

        let formatDescription = try soundFormatDescription()
        
        print("DEBUG Audio format description => \(formatDescription)")
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription).memory
        let format = AudioFormat(samplesRate: Int(asbd.mSampleRate), bitsDepth: Int(asbd.mBitsPerChannel), numberOfChannels: Int(asbd.mChannelsPerFrame))
        nativeAudioFormat = format
        return format
    }

    func audioReadingSettingsForFormat(audioFormat: AudioFormat) -> [String: AnyObject] {
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

    func readSamples(audioFormat: AudioFormat? = nil) throws {
        
        if let format = audioFormat {
            samplesReadAudioFormat = format
        }

        try prepareForReading()
        try read()
    }

    func prepareForReading() throws {
        
        let timerange = CMTimeRangeMake(kCMTimeZero, asset.duration)
        
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
        assetReader.timeRange = timerange
        
        if samplesHandler == nil {
            print("\(#function)[\(#line)] Caution!!! There is no samples handler")
        }

        self.readingRoutine = SamplesReadingRoutine(assetReader: assetReader, readerOutput: readerOutput, audioFormat: samplesReadAudioFormat, samplesHandler: samplesHandler)
    }
    
    func read() throws {
        
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
    
    init(assetReader: AVAssetReader, readerOutput: AVAssetReaderOutput, audioFormat: AudioFormat, samplesHandler: AudioSamplesHandler?) {
        self.assetReader  = assetReader
        self.readerOutput = readerOutput
        self.audioFormat  = audioFormat
        self.samplesHandler = samplesHandler
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
