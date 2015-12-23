//
//  DVGAudioSource.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation
import AVFoundation

final
class DVGAudioSource_: NSObject {
    var asset: AVAsset
    init(asset: AVAsset) {
        self.asset = asset
    }
    
    var audioFormat: AudioStreamBasicDescription?
    
    func readAudioFormat(completionBlock: (Bool, NSError?) -> ()) {
        
        do {
        
            let format = try self._readAudioFormat()
            self.audioFormat = format
            completionBlock(true, nil)
            
        } catch let error as NSError {

            completionBlock(true, error)

        } catch {}
    }
    
    
    var assetAudioTrack: AVAssetTrack? {
        return self.asset.tracksWithMediaType(AVMediaTypeAudio).first
    }

    
    func _readAudioFormat() throws -> AudioStreamBasicDescription {

        let sound = self.assetAudioTrack
        
        if sound == nil {
            
            let errorOut = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey : NSLocalizedString("This video does not contain sound", comment:"")
                ])
            
            throw errorOut
        }
        
        let formatDescription = sound!.formatDescriptions.first
        
        if formatDescription == nil {
            let errorOut = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey : NSLocalizedString("Invalid audio format", comment:"")
                ])
            
            throw errorOut
        }
        
        print("DEBUG Audio format description => \(formatDescription)")
        
        let channelsPerFrame = 2
        let bitsPerChannel   = 16
        
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription as! CMAudioFormatDescription).memory
        
        // Configure audio stream description
        var audioFormat               = AudioStreamBasicDescription()
        audioFormat.mSampleRate       = asbd.mSampleRate
        audioFormat.mFormatID         = kAudioFormatLinearPCM
        audioFormat.mFormatFlags      = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian
        audioFormat.mChannelsPerFrame = UInt32(channelsPerFrame)//< Stereo;
        audioFormat.mBitsPerChannel   = UInt32(bitsPerChannel)
        audioFormat.mBytesPerFrame    = UInt32(channelsPerFrame * sizeof(Int16))
        audioFormat.mBytesPerPacket   = UInt32(channelsPerFrame * sizeof(Int16))
        audioFormat.mFramesPerPacket  = 1//< Not compressed
        audioFormat.mReserved         = 0
        
        return audioFormat
    }
    
    func readAudioSamplesData(sampleBlock: (NSData!) -> (Bool)) throws {

        let timerange = CMTimeRangeMake(kCMTimeZero, self.asset.duration)
        
        let sound = self.assetAudioTrack
        
        if sound == nil {
            
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey : NSLocalizedString("This video does not contain sound", comment:"")
                ])
            throw error
        }
        
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: self.asset)
        } catch {
            throw error
        }
        
        
        let audioReadSettings: [String: AnyObject] = [
            AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatLinearPCM),
            AVSampleRateKey : 44100,
            AVNumberOfChannelsKey : 2,
            AVLinearPCMBitDepthKey : 16,
            AVLinearPCMIsBigEndianKey : false,
            AVLinearPCMIsFloatKey : false,
            AVLinearPCMIsNonInterleaved : false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput.init(track: sound!, outputSettings: audioReadSettings)

        assetReader.addOutput(readerOutput)
        assetReader.timeRange = timerange
        
        let started = assetReader.startReading()
        
        if !started {
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Asset reader not started", comment:"")
                ])
            throw assetReader.error ?? error
        }
        
        //DVGLog(@"DEBUG Started reading audio track");
        while assetReader.status == .Reading {
            var stop = false
            autoreleasepool { () -> () in
                
                let sampleBuffer = readerOutput.copyNextSampleBuffer()
                
                if sampleBuffer == nil {
                    return // continue while-loop (autorelease is closure in Swift)
                }
                
                // Get buffer
                let buffer = CMSampleBufferGetDataBuffer(sampleBuffer!)
                if buffer == nil {
                    fatalError()
                }
                
                let length = CMBlockBufferGetDataLength(buffer!)
                let bytes  = UnsafeMutablePointer<Void>.alloc(length)
//                // Append new data

                var returnedPointer = UnsafeMutablePointer<Int8>.alloc(0)
                CMBlockBufferAccessDataBytes(buffer!, 0, length, bytes, &returnedPointer)
                let data = NSData(bytesNoCopy: returnedPointer, length: length, freeWhenDone: false)
                
                autoreleasepool({ () -> () in
                    stop = sampleBlock(data)
                })

                if stop {
                    return
                }
            }
        }
        
        switch assetReader.status {
        case .Unknown, .Failed, .Cancelled, .Reading:
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Unknown error", comment:"")
                ])
            throw assetReader.error ?? error
        case .Completed:
            return
        }
    }
    
    
    
    
    
    
    
    
    func _readAudioSamplesData(sampleBlock: (UnsafePointer<Int16>!, length: Int) -> (Bool)) throws {
        
        let timerange = CMTimeRangeMake(kCMTimeZero, self.asset.duration)
        
        let sound = self.assetAudioTrack
        
        if sound == nil {
            
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey : NSLocalizedString("This video does not contain sound", comment:"")
                ])
            throw error
        }
        
        let assetReader: AVAssetReader
        do {
            assetReader = try AVAssetReader(asset: self.asset)
        } catch {
            throw error
        }
        
        
        let audioReadSettings: [String: AnyObject] = [
            AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatLinearPCM),
            AVSampleRateKey : 44100,
            AVNumberOfChannelsKey : 2,
            AVLinearPCMBitDepthKey : 16,
            AVLinearPCMIsBigEndianKey : false,
            AVLinearPCMIsFloatKey : false,
            AVLinearPCMIsNonInterleaved : false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput.init(track: sound!, outputSettings: audioReadSettings)
        
        assetReader.addOutput(readerOutput)
        assetReader.timeRange = timerange
        
        let started = assetReader.startReading()
        
        if !started {
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Asset reader not started", comment:"")
                ])
            throw assetReader.error ?? error
        }
        
        //DVGLog(@"DEBUG Started reading audio track");

        
        while assetReader.status == .Reading {
            var stop = false
            autoreleasepool { () -> () in
                
                let sampleBuffer = readerOutput.copyNextSampleBuffer()
                
                if sampleBuffer == nil {
                    return // continue while-loop (autorelease is closure in Swift)
                }
                
                // Get buffer
                let buffer = CMSampleBufferGetDataBuffer(sampleBuffer!)
                if buffer == nil {
                    fatalError()
                }
                
                let length = CMBlockBufferGetDataLength(buffer!)
                //                // Append new data
                
                let tempBytes       = UnsafeMutablePointer<Void>.alloc(length)
                var returnedPointer = UnsafeMutablePointer<Int8>()
                CMBlockBufferAccessDataBytes(buffer!, 0, length, tempBytes, &returnedPointer)
                let pointer = UnsafePointer<Int16>(returnedPointer)
                
                tempBytes.destroy()
                tempBytes.dealloc(length)
                
                sampleBlock(pointer, length: length)
            }
        }
        
        switch assetReader.status {
        case .Unknown, .Failed, .Cancelled, .Reading:
            let error = NSError(
                domain: "DVGAudioProcessorErrorDomain",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: NSLocalizedString("Unknown error", comment:"")
                ])
            throw assetReader.error ?? error
        case .Completed:
            return
        }
    }

}
