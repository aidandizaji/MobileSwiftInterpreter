//
//  Interpreter.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-18.
//

struct Interpreter {
    var valueStack: [InterpreterValue] = []
    //var to track which byte I am currently executing
    var pc: Int = 0
    var stringPool: [String] = []

    
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
    
    //old method of running ------- IGNORE
    //teaching the interpreter how to read and execute instructions, unmaned external parameter
    /* mutating func run(_ program: [OpCode]) -> Void {
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
    } */
    
    
    //adding new fuction to go over bytecode and not OpCode
    mutating func runBytecode(_ bytecode: [Bytecode]) {
        pc = 0
        
        while pc < bytecode.count {
            let insturction = bytecode[pc]
            pc += 1
            //optional binding
            if let op = Operation(rawValue: insturction.value) {
                switch op  {
                //if we are pushing an int
                case .pushInt:
                    let value = bytecode[pc].value
                    pc += 1
                    push(.nativeValue(value))
                    
                //if we are adding a value
                case .add:
                    add()
                
                    //if we are subtracting a value
                case .subtract:
                    subtract()
                    
                case .jump:
                    let offset = bytecode[pc].value
                    pc += 1
                    pc += offset
                    
                case .jumpIfFalse:
                    let offset = bytecode[pc].value
                    pc += 1
                    let condition = pop()?.boolValue ?? false
                    if condition == false {
                        pc += offset
                    }
                    
                case .lessThan:
                    let rhs = pop()?.intValue ?? 0
                    let lhs = pop()?.intValue ?? 0
                    push(.nativeValue(lhs < rhs))
                    
                case .equal:
                    let rhs = pop()?.intValue ?? 0
                    let lhs = pop()?.intValue ?? 0
                    push(.nativeValue(lhs == rhs))
                    
                case .pushBool:
                    let raw = bytecode[pc].value
                    pc += 1
                    push(.nativeValue(raw != 0))
                    
                case .pushString:
                    let index = bytecode[pc].value
                    pc += 1
                    push(.nativeValue(stringPool[index]))

                    
                }
                
            }
            
            
        }
    }
    
    //clean new convenience method
    mutating func run(_ program: [OpCode]) {
        let bytecode = compile(program)
        runBytecode(bytecode)
    }
    
    
    
}
