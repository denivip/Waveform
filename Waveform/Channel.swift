//
//  Types.swift
//  Virtual Func Test
//
//  Created by qqqqq on 09/01/16.
//  Copyright © 2016 qqqqq. All rights reserved.
//
import UIKit

public
protocol AbstractChannel: class {
    var totalCount: Int { get }
    var count: Int { get }
    var identifier: String { get }
    var maxValue: Double { get }
    var minValue: Double { get }

    subscript(index: Int) -> Double { get }
    func values() -> [Int]
}

extension AbstractChannel {
    public func values() -> [Int] {
        var array = [Int]()
        for index in 0..<self.count {
            array.append(self[index].int)
        }
        return array
    }
}

public
final
class Channel<T: NumberType>: AbstractChannel {
    
    let logicProvider: LogicProvider
    public init(logicProvider: LogicProvider) {
        self.logicProvider = logicProvider
        self.space = 0
        self.buffer = UnsafeMutablePointer<T>.alloc(0)
        self.buffer.initializeFrom(nil, count: 0)
        self.logicProvider.channel = self
    }
    
    public var blockSize = 1
    public var count: Int = 0
    public var totalCount: Int = 0
    public var identifier = ""
    public var maxValue: Double { return self._maxValue }
    public var minValue: Double { return self._minValue }
    
    private var currentBlockSize = 0
    private var space: Int = 0
    private var buffer: UnsafeMutablePointer<T>
    private var _maxValue = Double(CGFloat.min)
    private var _minValue = Double(CGFloat.max)

    public subscript(index: Int) -> Double {
        get { return self.buffer[index].double }
    }

    public func handleValue(value: Double) {
        if currentBlockSize == blockSize {
            self.clear()
            currentBlockSize = 0
        }
        currentBlockSize++
        self.logicProvider.handleValue(value)
    }
    
    func appendValueToBuffer(value: Double) {

        dispatch_async(dispatch_get_main_queue()) { 
            if self._maxValue < value { self._maxValue = value }
            if self._minValue > value { self._minValue = value }

            if self.space == self.count {
                let newSpace = max(self.space * 2, 16)
                let newPtr = UnsafeMutablePointer<T>.alloc(newSpace)
                
                newPtr.moveInitializeFrom(self.buffer, count: self.count)
                
                self.buffer.dealloc(self.count)
                
                self.buffer = newPtr
                self.space = newSpace
            }
            (self.buffer + self.count).initialize(T(value))
            self.count++
        }
    }

    private func clear() {
        self.logicProvider.clear()
    }
    
    public func finalize() {
        self.totalCount = self.count
        print(self.space, self.count, self.totalCount)
        //TODO: Clear odd space
        self.clear()
    }
    
    deinit {
        buffer.destroy(count)
        buffer.dealloc(count)
    }
}

private protocol LogicUser: class {
    func appendValueToBuffer(value: Double)
    var blockSize: Int { get }
}

extension Channel: LogicUser {}

public
class LogicProvider: Identifiable {
    weak private var channel: LogicUser?
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
