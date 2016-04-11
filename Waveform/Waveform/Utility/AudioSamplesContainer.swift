//
//  AudioSamplesContainer.swift
//  Waveform
//
//  Created by developer on 11/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation
struct AudioSamplesContainer<T> {
    let buffer: UnsafePointer<T>
    let samplesCount: Int
    let numberOfChannels: Int
    
    init<U>(buffer: UnsafePointer<U>, length: Int, numberOfChannels: Int) {
        self.buffer           = UnsafePointer<T>(buffer)
        self.samplesCount     = length * sizeof(U)/sizeof(T) / numberOfChannels
        self.numberOfChannels = numberOfChannels
    }
    
    func sample(channelIndex channelIndex: Int = 0, sampleIndex: Int) -> T {
        assert(channelIndex < numberOfChannels)
        assert(sampleIndex < samplesCount)
        return buffer[numberOfChannels * sampleIndex + channelIndex]
    }
}