//
//  Compiler.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

func compile(_ program: [OpCode]) -> [Bytecode] {
    var bytecode: [Bytecode] = []

    for instruction in program {
        switch instruction {

        case .pushInt(let value):
            bytecode.append(Bytecode(value: Operation.pushInt.rawValue))
            bytecode.append(Bytecode(value: value))

        case .pushBool(let value):
            bytecode.append(Bytecode(value: Operation.pushBool.rawValue))
            bytecode.append(Bytecode(value: value ? 1 : 0))

        case .add:
            bytecode.append(Bytecode(value: Operation.add.rawValue))

        case .subtract:
            bytecode.append(Bytecode(value: Operation.subtract.rawValue))
            
        case .pushString(let value):
            let index = stringPool.count
            stringPool.append(value)
            bytecode.append(Bytecode(value: Operation.pushString.rawValue))
            bytecode.append(Bytecode(value: index))

        }
    }

    return bytecode
}
