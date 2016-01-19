//
//  Types.swift
//  Virtual Func Test
//
//  Created by qqqqq on 09/01/16.
//  Copyright © 2016 qqqqq. All rights reserved.
//

public
protocol AbstractChannel: class {
    var totalCount: Int { get }
    var count: Int { get }
    var identifier: String { get }
    var maxValue: Double { get }
    var minValue: Double { get }

    subscript(index: Int) -> Double { get }
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
        if count >= totalCount { return }
        
        if _maxValue < value { _maxValue = value }
        if _minValue > value { _minValue = value }
        
        if space == count {
            let newSpace = max(space * 2, 16)
            let newPtr = UnsafeMutablePointer<T>.alloc(newSpace)
            
            newPtr.moveInitializeFrom(buffer, count: count)
            
            buffer.dealloc(count)
            
            buffer = newPtr
            space = newSpace
        }
        (buffer + count).initialize(T(value))
        count++
    }
    
    private func clear() {
        self.logicProvider.clear()
    }
    
    public func finalize() {
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
class LogicProvider {
    weak private var channel: LogicUser?
    class var identifier: String { return "" }
    var identifier: String { return self.dynamicType.identifier }
    public required init(){}

    public func handleValue(value: Double) {}
    public func clear() {}
}

public
final
class MaxValueLogicProvider: LogicProvider {
    class override var identifier: String { return "max" }
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
    class override var identifier: String { return "avg" }
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
    class override var identifier: String { return "max" }
    private var max = -40.0
    public required init(){}
    
    public override func handleValue(value: Double) {
        if value > max {
            max = value
        }
    }
    
    public override func clear() {
        self.channel?.appendValueToBuffer(max)
        max = -40.0
    }
}

public
final
class AudioAverageValueLogicProvider: LogicProvider {
    class override var identifier: String { return "avg" }
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
