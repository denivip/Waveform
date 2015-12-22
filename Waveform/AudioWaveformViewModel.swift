//
//  AudioWaveformViewModel.swift
//  Waveform
//
//  Created by developer on 22/12/15.
//  Copyright © 2015 developer. All rights reserved.
//

import Foundation

final
class AudioWaveformViewModel: NSObject, AudioWaveformViewDataSource {
    
    var onMaxPulse: () -> (Int16) = { return 0 }
    var onCurrentPulsesCount: () -> (Int) = { return 0 }
    var onTotalPulsesCount: () -> (Int) = { return 0 }
    var onPulseAtIndex: (Int) -> (Int16) = { _ in return 0 }
    
    var maxPulse: Int16 { return self.onMaxPulse() }
    var currentPulsesCount: Int { return self.onCurrentPulsesCount() }
    var totalPulsesCount: Int { return self.onTotalPulsesCount() }
    
    func pulseAtIndex(index: Int) -> Int16 {
        return self.onPulseAtIndex(index)
    }
}
