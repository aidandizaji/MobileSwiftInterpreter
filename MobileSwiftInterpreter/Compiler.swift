//
//  Compiler.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

struct CompiledProgram {
    let bytecode: Bytecode
    let stringPool: [String]
    let symbolPool: [String]
    let typeTable: [InterpreterType]
}

struct Compiler {
    var bytecode: Bytecode
    var stringPool: [String]
    var symbolPool: [String]
    var typeTable: [InterpreterType]
    var localTable: [String: Int]

    init() {
        self.bytecode = Bytecode()
        self.stringPool = []
        self.symbolPool = []
        self.typeTable = []
        self.localTable = [:]
    }

    mutating func emit(_ op: Operation) {
        bytecode.appendOp(op)
    }

    mutating func emitInt(_ value: Int) {
        bytecode.appendInt(value)
    }

    mutating func emitBool(_ value: Bool) {
        bytecode.appendBool(value)
    }

    mutating func emitString(_ value: String) -> Int {
        if let existing = stringPool.firstIndex(of: value) {
            return existing
        }
        let index = stringPool.count
        stringPool.append(value)
        return index
    }

    mutating func emitSymbol(_ value: String) -> Int {
        if let existing = symbolPool.firstIndex(of: value) {
            return existing
        }
        let index = symbolPool.count
        symbolPool.append(value)
        return index
    }

    mutating func emitPushString(_ value: String) {
        let index = emitString(value)
        emit(.pushString)
        emitInt(index)
    }

    mutating func emitPushInt(_ value: Int) {
        emit(.pushInt)
        emitInt(value)
    }

    mutating func emitPushBool(_ value: Bool) {
        emit(.pushBool)
        emitBool(value)
    }

    mutating func allocateLocal(_ name: String) -> Int {
        if let existing = localTable[name] {
            return existing
        }
        let slot = localTable.count
        localTable[name] = slot
        return slot
    }

    mutating func declareType(name: String, fieldNames: [String]) {
        let type = InterpreterType(name: name, fieldNames: fieldNames)
        typeTable.append(type)
    }

    mutating func emitJump(_ op: Operation) -> Int {
        emit(op)
        let offsetLocation = bytecode.count
        emitInt(0)
        return offsetLocation
    }

    mutating func patchJump(at offsetLocation: Int, to target: Int) {
        let pcAfterOperand = offsetLocation + Bytecode.intByteWidth
        let offset = target - pcAfterOperand
        bytecode.writeInt(offset, at: offsetLocation)
    }

    func finish() -> CompiledProgram {
        CompiledProgram(
            bytecode: bytecode,
            stringPool: stringPool,
            symbolPool: symbolPool,
            typeTable: typeTable
        )
    }
}
