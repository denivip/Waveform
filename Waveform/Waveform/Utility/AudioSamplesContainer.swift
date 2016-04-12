//
//  AudioSamplesContainer.swift
//  Waveform
//
//  Created by developer on 11/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

protocol _AudioSamplesContainer {
    var buffer: UnsafePointer<Int16> { get }
    var numberOfChannels: Int { get }
    var samplesCount: Int { get }
    func sample(channelIndex channelIndex: Int, sampleIndex: Int) -> Int16
}

struct AudioSamplesContainer: _AudioSamplesContainer {
    let buffer: UnsafePointer<Int16>
    let samplesCount: Int
    let numberOfChannels: Int
    
    init(buffer: UnsafePointer<Int8>, length: Int, numberOfChannels: Int) {
        self.buffer           = UnsafePointer<Int16>(buffer)
        self.samplesCount     = length * sizeof(Int8)/sizeof(Int16) / numberOfChannels
        self.numberOfChannels = numberOfChannels
    }
    
    func sample(channelIndex channelIndex: Int, sampleIndex: Int) -> Int16 {
        assert(channelIndex < numberOfChannels)
        assert(sampleIndex < samplesCount)
        return buffer[numberOfChannels * sampleIndex + channelIndex]
    }
}