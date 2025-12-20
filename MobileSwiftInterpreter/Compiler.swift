//
//  Compiler.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

func compile(_ program: [OpCode]) -> [Bytecode] {
    var bytecode: [Bytecode] = []

    
    //cant use a loop here because we can not tell the difference between opcode vs operand. For - Each Functionalilty breaks down.
    for instruction in program {
        switch instruction {
        case .pushInt(let value):
            //need to add the correct value for .pushint
            bytecode.append(Bytecode(value: Operation.pushInt.rawValue))
            bytecode.append(Bytecode(value: value))
            
        case .add:
            break
        case .subtract:
            break
        }
    }

    return bytecode
}
