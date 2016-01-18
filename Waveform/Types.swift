//
//  Types.swift
//  Virtual Func Test
//
//  Created by qqqqq on 09/01/16.
//  Copyright © 2016 qqqqq. All rights reserved.
//

import Foundation
import UIKit

public
protocol NumberType {
    init(_ v: Int)
    init(_ v: Int16)
    init(_ v: Double)
    init(_ v: Float)
    init(_ v: CGFloat)
    var int: Int { get }
    var int16: Int16 { get }
    var double: Double { get }
    var float: Float { get }
    var cgfloat: CGFloat { get }
}

extension Int: NumberType {
    public var int: Int { return Int(self) }
    public var int16: Int16 { return Int16(self) }
    public var double: Double { return Double(self) }
    public var float: Float { return Float(self) }
    public var cgfloat: CGFloat { return CGFloat(self) }
}

extension Int16: NumberType {
    public var int: Int { return Int(self) }
    public var int16: Int16 { return Int16(self) }
    public var double: Double { return Double(self) }
    public var float: Float { return Float(self) }
    public var cgfloat: CGFloat { return CGFloat(self) }
}

extension Double: NumberType {
    public var int: Int { return Int(self) }
    public var int16: Int16 { return Int16(self) }
    public var double: Double { return Double(self) }
    public var float: Float { return Float(self) }
    public var cgfloat: CGFloat { return CGFloat(self) }
}

extension Float: NumberType {
    public var int: Int { return Int(self) }
    public var int16: Int16 { return Int16(self) }
    public var double: Double { return Double(self) }
    public var float: Float { return Float(self) }
    public var cgfloat: CGFloat { return CGFloat(self) }
}

extension CGFloat: NumberType {
    public init(_ v: CGFloat) { self = v }
    public var int: Int { return Int(self) }
    public var int16: Int16 { return Int16(self) }
    public var double: Double { return Double(self) }
    public var float: Float { return Float(self) }
    public var cgfloat: CGFloat { return CGFloat(self) }
}

public
protocol ChannelProtocol: class {
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
class Channel<T: NumberType>: ChannelProtocol {
    
    let logicProvider: LogicProvider
    public init(logicProvider: LogicProvider) {
        self.logicProvider = logicProvider
        
        self.space = 0
        self.buffer = UnsafeMutablePointer<T>.alloc(0)
        self.buffer.initializeFrom(nil, count: 0)
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
        self.appendValueToBuffer(self.logicProvider.valueForSave())
        self.logicProvider.clear()
        self.onChanged(self)
    }
    
    public
    func finalize() {
        print(self.space, self.count)
        self.clear()
    }
    
    deinit {
        buffer.destroy(count)
        buffer.dealloc(count)
    }
    
    final
    var onChanged: (Channel) -> () = {_ in return}
}

public
class LogicProvider {
    class var identifier: String { return "" }
    var identifier: String { return self.dynamicType.identifier }
    public required init(){}
    public func valueForSave() -> NumberWrapper {
        return NumberWrapper(0)
    }
    public func handleValue(value: NumberWrapper) {}
    public func clear() {}
}

public
final
class SearchMaxValueLogicProvider: LogicProvider {
    class override var identifier: String { return "SearchMaxValue" }
    var globalMax: NumberWrapper?
    private var max: NumberWrapper?
    public required init(){}

    public final override func handleValue(value: NumberWrapper) {
        if max == nil {
            max = value
        } else if value > max! {
            max = value
        }
    }
    public final override func valueForSave() -> NumberWrapper {
        return max ?? NumberWrapper.int(0)
    }
    public final override func clear() {
        if globalMax == nil || (max != nil && globalMax! > max!) {
            globalMax = max
        }
        max = nil
    }
}

public
enum NumberWrapper {
    case int(Int)
    case double(Double)
    
    public func value<T: NumberType>() -> T {
        switch self {
        case .int(let v):
            return T(v)
        case .double(let v):
            return T(v)
        }
    }
}

public
extension NumberWrapper {
    public init(_ value: Int) {
        self = .int(value)
    }
    public init(_ value: Int16) {
        self = .int(Int(value))
    }
    public init(_ value: Float) {
        self = .double(Double(value))
    }
    public init(_ value: CGFloat) {
        self = .double(Double(value))
    }
    public init(_ value: Double) {
        self = .double(value)
    }
}

public
func +(l:NumberWrapper, r: NumberWrapper) -> NumberWrapper {
    switch (l, r) {
    case (.int(let left), .int(let right)):
        return NumberWrapper.int(left + right)
    case (.int(let left), .double(let right)):
        return NumberWrapper.double(Double(left) + right)
    case (.double(let left), .int(let right)):
        return NumberWrapper.double(left + Double(right))
    case (.double(let left), .double(let right)):
        return NumberWrapper.double(left + right)
    }
}

public
func <(l:NumberWrapper, r: NumberWrapper) -> Bool {
    switch (l, r) {
    case (.int(let left), .int(let right)):
        return left < right
    case (.int(let left), .double(let right)):
        return Double(left) < right
    case (.double(let left), .int(let right)):
        return left < Double(right)
    case (.double(let left), .double(let right)):
        return left < right
    }
}

public
func >(l:NumberWrapper, r: NumberWrapper) -> Bool {
    switch (l, r) {
    case (.int(let left), .int(let right)):
        return left > right
    case (.int(let left), .double(let right)):
        return Double(left) > right
    case (.double(let left), .int(let right)):
        return left > Double(right)
    case (.double(let left), .double(let right)):
        return left > right
    }
}

public
func measure(block: () -> ()) {
    let date = NSDate()
    block()
    let s = String(format:"%.4f", -date.timeIntervalSinceNow)
    print(s)
}
