//
//  AudioReaderSettings.swift
//  Waveform
//
//  Created by developer on 11/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

public
class AudioFormat: NSObject {
    let samplesRate: Int
    let bitsDepth: Int
    let numberOfChannels: Int
    init(samplesRate: Int, bitsDepth: Int, numberOfChannels: Int) {
        self.samplesRate = samplesRate
        self.bitsDepth = bitsDepth
        self.numberOfChannels = numberOfChannels
    }
}