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
    
    
    mutating func add() -> Void {
        if valueStack.count < 2 {
            return
        }
        
        guard let rhs = pop()?.intValue else {
            return
        }
        guard let lhs = pop()?.intValue else {
            return
        }
        
        //add on to the value stack, we need to add an InterpreterValue
        push(.nativeValue(rhs + lhs))
    }
    
    mutating func subtract() -> Void {
        //got to make sure there is enough on the stack
        if valueStack.count < 2 {
            return
        }
        
        guard let rhs = pop()?.intValue else {
            return
        }
        
        guard let lhs = pop()?.intValue else {
            return
        }
        
        //add on to the valeu stack again jsut like add
        push(.nativeValue(lhs - rhs))
    }
    
    //teaching the interpreter how to read and execute instructions, unmaned external parameter
    mutating func run(_ program: [OpCode]) -> Void {
        //loop over ValueStack
        for instruction in program {
            switch instruction {
            case .pushInt(let value):
                //push value
                push(.nativeValue(value))
                
            case .add:
                add()
                
            case .subtract:
                subtract()
                
            }
        }
    }
    
    
    
}
