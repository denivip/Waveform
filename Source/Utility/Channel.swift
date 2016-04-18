//
//  Types.swift
//  Virtual Func Test
//
//  Created by qqqqq on 09/01/16.
//  Copyright © 2016 qqqqq. All rights reserved.
//
import Foundation

public
final
class Channel {
    
    let logicProvider: LogicProvider
    let buffer: Buffer
    public init(logicProvider: LogicProvider, buffer: Buffer = GenericBuffer<Int>()) {
        self.logicProvider = logicProvider
        self.buffer = buffer
        self.logicProvider.channel = self
    }
    
    public var blockSize = 1
    public var count: Int { return buffer.count }
    public var totalCount: Int = 0
    lazy public var identifier: String = { return "\(self.logicProvider.dynamicType)" }()
    
    private var currentBlockSize = 0
    public var maxValue: Double { return buffer.maxValue }
    public var minValue: Double { return buffer.minValue }
    var onUpdate: () -> () = {}

    public subscript(index: Int) -> Double {
        get {
            return buffer.valueAtIndex(index)
        }
    }
    
    public func handleValue<U: NumberType>(value: U) {
        if currentBlockSize == blockSize {
            self.clear()
            currentBlockSize = 0
        }
        currentBlockSize += 1
        self.logicProvider.handleValue(value.double)
    }
    
    func appendValueToBuffer(value: Double) {
        buffer.appendValue(value)
        onUpdate()
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
}