//
//  Types.swift
//  Virtual Func Test
//
//  Created by qqqqq on 09/01/16.
//  Copyright © 2016 qqqqq. All rights reserved.
//
import Foundation

public
protocol AbstractChannel: class {
    var totalCount: Int { get }
    var count: Int { get }
    var identifier: String { get }
    var maxValue: Double { get }
    var minValue: Double { get }

    subscript(index: Int) -> Double { get }
    func handleValue<U: NumberType>(value: U)
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
    private var _maxValue = -Double.infinity
    private var _minValue = Double.infinity

    public subscript(index: Int) -> Double {
        get { return self.buffer[index].double }
    }

    public func handleValue<U: NumberType>(value: U) {
        if currentBlockSize == blockSize {
            self.clear()
            currentBlockSize = 0
        }
        currentBlockSize++
        self.logicProvider.handleValue(value.double)
    }
    
    func appendValueToBuffer(value: Double) {

//        dispatch_async(dispatch_get_main_queue()) { 
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
//        }
    }

    private func clear() {
        self.logicProvider.clear()
    }
    
    public func complete() {

        self.totalCount = self.count
        print(self.blockSize, self.count, self.totalCount)
        //TODO: Clear odd space
        self.clear()
    }
    
    deinit {
        //TODO: clear space not count
        buffer.destroy(count)
        buffer.dealloc(count)
    }
}