//
//  InterpreterValue.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-17.
//

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
    
}
