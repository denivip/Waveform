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
    subscript(index: Int) -> Int { get }
    subscript(index: Int) -> Int16 { get }
    subscript(index: Int) -> Double { get }
    subscript(index: Int) -> Float { get }
    subscript(index: Int) -> CGFloat { get }
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
    
    public final var blockSize = 1
    private var currentBlockSize = 0
    
    private var space: Int = 0
    public final var count: Int = 0
    public final var totalCount: Int = 0

    public var identifier = ""
    

    public final subscript(index: Int) -> Int {
        get { return self.buffer[index].int }
    }
    public final subscript(index: Int) -> Int16 {
        get { return self.buffer[index].int16 }
    }
    public final subscript(index: Int) -> Double {
        get { return self.buffer[index].double }
    }
    public final subscript(index: Int) -> Float {
        get { return self.buffer[index].float }
    }
    public final subscript(index: Int) -> CGFloat {
        get { return self.buffer[index].cgfloat }
    }

    public
    final
    func handleValue(value: NumberWrapper) {
        if currentBlockSize == blockSize {
            self.clear()
            currentBlockSize = 0
        }
        currentBlockSize++
        self.logicProvider.handleValue(value)
    }
    
    private var buffer: UnsafeMutablePointer<T>
    
    final
    func appendValueToBuffer(value: NumberWrapper) {
        if space == count {
            let newSpace = max(space * 2, 16)
            let newPtr = UnsafeMutablePointer<T>.alloc(newSpace)
            
            newPtr.moveInitializeFrom(buffer, count: count)
            
            buffer.dealloc(count)
            
            buffer = newPtr
            space = newSpace
        }
        (buffer + count).initialize(value.value())
        count++
    }
    
    private
    func clear() {
        self.logicProvider.clear()
        self.onChanged(self)
    }
    
    public
    func finalize() {
        print(self.space, self.count, self.totalCount)
        //TODO: Clear odd space
        self.clear()
    }
    
    deinit {
        buffer.destroy(count)
        buffer.dealloc(count)
    }
    
    final
    var onChanged: (Channel) -> () = {_ in return}
}

private protocol LogicUser: class {
    func appendValueToBuffer(value: NumberWrapper)
}

extension Channel: LogicUser {}

public
class LogicProvider {
    weak private var channel: LogicUser?
    class var identifier: String { return "" }
    var identifier: String { return self.dynamicType.identifier }
    public required init(){}

    public func handleValue(value: NumberWrapper) {}
    public func clear() {}
}

public
final
class MaxValueLogicProvider: LogicProvider {
    class override var identifier: String { return "max" }
    private var max: NumberWrapper?
    public required init(){}

    public final override func handleValue(value: NumberWrapper) {
        if max == nil {
            max = value
        } else if value > max! {
            max = value
        }
    }

    public final override func clear() {
        self.channel?.appendValueToBuffer(max ?? NumberWrapper.int(0))
        max = nil
    }
}

public
final
class AverageValueLogicProvider: LogicProvider {
    class override var identifier: String { return "avg" }
    private var summ = NumberWrapper.double(0.0)
    var count = 0
    public required init(){}
    
    public final override func handleValue(value: NumberWrapper) {
        summ = summ + value
        count++
    }
    
    public final override func clear() {
        self.channel?.appendValueToBuffer(summ/count)
        summ = NumberWrapper.double(0.0)
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
