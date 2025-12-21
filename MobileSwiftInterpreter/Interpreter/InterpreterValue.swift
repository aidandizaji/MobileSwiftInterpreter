//
//  InterpreterValue.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-17.
//

#if canImport(SwiftUI)
import SwiftUI
#endif

//create the first enum
enum InterpreterValue {
    case nativeValue(Any)
    case customInstance(CustomInstance)
}

extension InterpreterValue {
    
    //optional downcasting for Int
    var intValue: Int? {
        switch self {
        //must perform optional downcasting (aka safe casting)
        case .nativeValue(let value):
            return value as? Int
        case .customInstance:
            return nil
        }
    }
    
    //optional downcasting for String
    var stringValue: String? {
        switch self {
        case .nativeValue(let value):
            //perform the optional down cast
            return value as? String
        case .customInstance:
            return nil
        }
    }
    
    //optional downcasting for Bool
    var boolValue: Bool? {
        switch self {
        //perform the optional down cast
        case .nativeValue(let value):
            return value as? Bool
        case .customInstance:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .nativeValue(let value):
            if let doubleValue = value as? Double {
                return doubleValue
            }
            if let intValue = value as? Int {
                return Double(intValue)
            }
            return nil
        case .customInstance:
            return nil
        }
    }

    var doubleRangeValue: ClosedRange<Double>? {
        switch self {
        case .nativeValue(let value):
            if let range = value as? ClosedRange<Double> {
                return range
            }
            if let range = value as? ClosedRange<Int> {
                return Double(range.lowerBound)...Double(range.upperBound)
            }
            return nil
        case .customInstance:
            return nil
        }
    }

    #if canImport(SwiftUI)
    var viewValue: AnyView? {
        switch self {
        case .nativeValue(let value):
            return value as? AnyView
        case .customInstance:
            return nil
        }
    }

    var bindingValue: AnyBinding? {
        switch self {
        case .nativeValue(let value):
            return value as? AnyBinding
        case .customInstance:
            return nil
        }
    }

    var actionValue: ActionHandler? {
        switch self {
        case .nativeValue(let value):
            return value as? ActionHandler
        case .customInstance:
            return nil
        }
    }
    #else
    var viewValue: Any? {
        return nil
    }

    var bindingValue: Any? {
        return nil
    }

    var actionValue: Any? {
        return nil
    }
    #endif
    
}
