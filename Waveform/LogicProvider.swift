//
//  LogicProvider.swift
//  Waveform
//
//  Created by developer on 25/01/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

internal protocol LogicUser: class {
    func appendValueToBuffer(value: Double)
    var blockSize: Int { get }
}

extension Channel: LogicUser {}

public
class LogicProvider: Identifiable {
    weak internal var channel: LogicUser?
    public required init(){}
    
    public func handleValue(value: Double) {}
    public func clear() {}
}

public
final
class MaxValueLogicProvider: LogicProvider {
    private var max: Double?
    public required init(){}
    
    public override func handleValue(value: Double) {
        if max == nil {
            max = value
        } else if value > max! {
            max = value
        }
    }
    
    public override func clear() {
        self.channel?.appendValueToBuffer(max ?? 0)
        max = nil
    }
}

public
final
class AverageValueLogicProvider: LogicProvider {
    private var summ = 0.0
    var count = 0
    public required init(){}
    
    public override func handleValue(value: Double) {
        summ = summ + value
        count++
    }
    
    public override func clear() {
        self.channel?.appendValueToBuffer(summ/Double(count))
        summ = 0.0
        count = 0
    }
}


public
final
class AudioMaxValueLogicProvider: LogicProvider {
    private var max = Double(Int16.min)//-40.0
    public required init(){}
    
    public override func handleValue(var value: Double) {
        value = abs(value)
        if value > max {
            max = value
        }
    }
    
    public override func clear() {
        self.channel?.appendValueToBuffer(min(max, Double(Int16.max)))
        max = Double(Int16.min)//-40.0
    }
}

public
final
class AudioAverageValueLogicProvider: LogicProvider {
    private var summ = 0.0
    var count = 0
    public required init(){}
    
    public override func handleValue(value: Double) {
        summ = summ + abs(value)
        count++
    }
    
    public override func clear() {
        self.channel?.appendValueToBuffer(summ/Double(count))
        summ = 0.0
        count = 0
    }
}

public
func measure(block: () -> ()) {
    let date = NSDate()
    block()
    let s = String(format:"%.4f", -date.timeIntervalSinceNow)
    print(s)
}
