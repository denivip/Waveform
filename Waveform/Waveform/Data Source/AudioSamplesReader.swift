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
            completionBlock(self.nativeAudioFormat, nil)
            
        } catch let error as SamplesReaderError {
            
            completionBlock(nil, error)
        
        } catch let error {

            fatalError("unknown error:\(error)")
        }
    }
    
    func assetAudioTrack() throws -> AVAssetTrack {
        guard let sound = self.asset.tracksWithMediaType(AVMediaTypeAudio).first else {
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

    func readSamples(audioFormat: AudioFormat? = nil, samplesHandler: AudioSamplesHandler) throws {
        
        if let format = audioFormat {
            samplesReadAudioFormat = format
        }

        self.samplesHandler = samplesHandler
        try prepareForReading()
        try read()
    }

    func prepareForReading() throws {
        
        let timerange = CMTimeRangeMake(kCMTimeZero, self.asset.duration)
        
        let sound = try self.assetAudioTrack()
        
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: self.asset)
        } catch let error as NSError {
            throw SamplesReaderError.UnknownError(error)
        }
    
        let settings = self.audioReadingSettingsForFormat(samplesReadAudioFormat)
        
        let readerOutput = AVAssetReaderTrackOutput(track: sound, outputSettings: settings)
        
        assetReader.addOutput(readerOutput)
        assetReader.timeRange = timerange
        
        self.readingRoutine = SamplesReadingRoutine(assetReader: assetReader, readerOutput: readerOutput, audioFormat: samplesReadAudioFormat)
    }
    
    func read() throws {
        
        guard let readingRoutine = self.readingRoutine else {
            throw SamplesReaderError.SampleReaderNotReady
        }
        
        try readingRoutine.startReading()
        
        readingRoutine.samplesHandler = self.samplesHandler
        
        while readingRoutine.isReading {
            do {
                try readingRoutine.readNextSamples()
            } catch (_ as NoMoreSampleBuffersAvailable) {
                break
            } catch {
                readingRoutine.cancelReading()
                throw error
            }
        }
        
        try readingRoutine.checkStatusOfAssetReaderOnComplete()
    }
}

private struct NoMoreSampleBuffersAvailable: ErrorType {}

private final class SamplesReadingRoutine {
    
    let assetReader: AVAssetReader
    let readerOutput: AVAssetReaderOutput
    let audioFormat: AudioFormat
    
    weak var samplesHandler: AudioSamplesHandler?
    
    init(assetReader: AVAssetReader, readerOutput: AVAssetReaderOutput, audioFormat: AudioFormat) {
        self.assetReader  = assetReader
        self.readerOutput = readerOutput
        self.audioFormat  = audioFormat
    }
    
    var isReading: Bool {
        return self.assetReader.status == .Reading
    }
    
    func startReading() throws  {
        if !assetReader.startReading() {
            throw SamplesReaderError.CantReadSamples(assetReader.error)
        }
    }

    func cancelReading() {
        self.assetReader.cancelReading()
    }
    
    let tempBytes = UnsafeMutablePointer<Void>.alloc(100_000)
    var returnedPointer: UnsafeMutablePointer<Int8> = nil
    
    func readNextSamples() throws {
        
        var error: ErrorType?
        
        autoreleasepool {
    
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                error = NoMoreSampleBuffersAvailable() // continue while-loop (autorelease is closure in Swift)
                return
            }
            
            // Get buffer
            guard let buffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                error = SamplesReaderError.UnknownError(nil)
                return
            }
            
            let length = CMBlockBufferGetDataLength(buffer)
            
            // Append new data
            
            CMBlockBufferAccessDataBytes(buffer, 0, length, tempBytes, &returnedPointer)
        
            let samplesContainer = AudioSamplesContainer(buffer: returnedPointer, length: length, numberOfChannels: audioFormat.numberOfChannels)
    
            samplesHandler?.handleSamples(samplesContainer)
        }
        
        if error != nil {
            throw(error!)
        }
        
        return
    }
    
    func checkStatusOfAssetReaderOnComplete() throws {
        switch assetReader.status {
        case .Unknown, .Failed, .Reading:
            throw SamplesReaderError.UnknownError(assetReader.error)
        case .Cancelled, .Completed:
            return
        }
    }
    
    deinit {
        tempBytes.destroy()
        tempBytes.dealloc(100_000)
    }
}
