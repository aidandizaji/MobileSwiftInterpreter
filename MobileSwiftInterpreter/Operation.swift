//
//  Operation.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

enum Operation: UInt8 {
    case pushInt = 0
    case pushBool
    case pushString
    case add
    case subtract
    case multiply
    case divide
    case lessThan
    case equal
    case jump
    case jumpIfFalse
    case loadLocal
    case storeLocal
    case callMethod
    case callFunction
    case getProperty
    case constructType
    case returnValue
}
