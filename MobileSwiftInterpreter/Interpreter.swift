//
//  Interpreter.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-18.
//

struct Interpreter {
    var valueStack: [InterpreterValue] = []
    
    //must be able to push and pop to the stack
    
    //push fucntion with unnamed external parameter
    mutating func push(_ value: InterpreterValue) -> Void {
        
        valueStack.append(value)
        return
    }
    
    //pop fucntion
    mutating func pop() -> InterpreterValue? {
        
        //ensure the stack is not empty
        if valueStack.isEmpty {
            return nil
        }
        else {
            return valueStack.removeLast()
        }
        
    }
    
}
