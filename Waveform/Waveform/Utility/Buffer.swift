//
//  Buffer.swift
//  Channel Performance test
//
//  Created by developer on 15/04/16.
//  Copyright © 2016 developer. All rights reserved.
//

import Foundation

public
class Buffer {
    typealias DefaultNumberType = Double
    var maxValue = -Double.infinity
    var minValue = Double.infinity
    var count = 0
    var buffer: UnsafeMutablePointer<Void> = nil
    var _buffer: UnsafeMutablePointer<DefaultNumberType> = nil
    private var space = 0

    func appendValue(value: Double) {
        if maxValue < value { maxValue = value }
        if minValue > value { minValue = value }
        
        if space == count {
            let newSpace = max(space * 2, 16)
            self.moveSpaceTo(newSpace)
            _buffer = UnsafeMutablePointer<DefaultNumberType>(buffer)
        }
        (UnsafeMutablePointer<DefaultNumberType>(buffer) + count).initialize(value)
        count += 1
    }
    private
    func moveSpaceTo(newSpace: Int) {
        let newPtr = UnsafeMutablePointer<DefaultNumberType>.alloc(newSpace)
        
        newPtr.moveInitializeFrom(UnsafeMutablePointer<DefaultNumberType>(buffer), count: count)
        
        buffer.dealloc(count)
        
        buffer = UnsafeMutablePointer<Void>(newPtr)
        space = newSpace
    }
    func valueAtIndex(index: Int) -> Double {
        return _buffer[index]
    }
}

final
class GenericBuffer<T: NumberType>: Buffer {
    var __buffer: UnsafeMutablePointer<T> = nil

    override final func appendValue(value: Double) {

        if maxValue < value { maxValue = value }
        if minValue > value { minValue = value }
        
        if space == count {
            let newSpace = max(space * 2, 16)
            self.moveSpaceTo(newSpace)
        }
        (__buffer + count).initialize(T(value))
        count += 1
    }
    
    override final func moveSpaceTo(newSpace: Int) {
        let newPtr = UnsafeMutablePointer<T>.alloc(newSpace)
        
        newPtr.moveInitializeFrom(__buffer, count: count)
        
        __buffer.dealloc(count)
        
        __buffer = newPtr
        space = newSpace
    }
    override final func valueAtIndex(index: Int) -> Double {
        return __buffer[index].double
    }
    deinit {
        __buffer.destroy(space)
        __buffer.dealloc(space)
    }
}