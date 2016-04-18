//
//  NumberTypes.swift
//  Waveform
//
//  Created by qqqqq on 19/01/16.
//  Copyright © 2016 developer. All rights reserved.
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

func abs(number: NumberWrapper) -> NumberWrapper {
    switch number {
    case .int(let v):
        return NumberWrapper( abs(v))
    case .double(let v):
        return NumberWrapper( abs(v))
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

func /(l:NumberWrapper, r: Int) -> NumberWrapper {
    switch l {
    case .int(let left):
        return NumberWrapper.double(Double(left) / Double(r))
    case .double(let left):
        return NumberWrapper.double(left / Double(r))
    }
}

func /(l:NumberWrapper, r: Double) -> NumberWrapper {
    switch l {
    case .int(let left):
        return NumberWrapper.double(Double(left) / r)
    case .double(let left):
        return NumberWrapper.double(left / Double(r))
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
