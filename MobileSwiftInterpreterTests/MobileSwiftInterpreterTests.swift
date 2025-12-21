//
//  MobileSwiftInterpreterTests.swift
//  MobileSwiftInterpreterTests
//
//  Created by Aidan Dizaji on 2025-12-17.
//

import XCTest
@testable import MobileSwiftInterpreter
#if canImport(SwiftUI)
import SwiftUI
#endif

final class MobileSwiftInterpreterTests: XCTestCase {
    func testBytecodeExecution() {
        var bytecode = Bytecode()
        bytecode.appendOp(.pushInt)
        bytecode.appendInt(2)
        bytecode.appendOp(.pushInt)
        bytecode.appendInt(3)
        bytecode.appendOp(.add)
        let program = CompiledProgram(
            bytecode: bytecode,
            stringPool: [],
            symbolPool: [],
            typeTable: []
        )
        var interpreter = Interpreter()
        XCTAssertNoThrow(try interpreter.run(program))
        XCTAssertEqual(interpreter.valueStack.last?.intValue, 5)
    }

    func testJumpOffsets() {
        var compiler = Compiler()
        compiler.emitPushBool(false)
        let jumpToElse = compiler.emitJump(.jumpIfFalse)
        compiler.emitPushInt(1)
        let jumpToEnd = compiler.emitJump(.jump)
        let elseTarget = compiler.bytecode.count
        compiler.patchJump(at: jumpToElse, to: elseTarget)
        compiler.emitPushInt(2)
        let endTarget = compiler.bytecode.count
        compiler.patchJump(at: jumpToEnd, to: endTarget)
        let program = compiler.finish()
        var interpreter = Interpreter()
        XCTAssertNoThrow(try interpreter.run(program))
        XCTAssertEqual(interpreter.valueStack.last?.intValue, 2)
    }

    func testExpressionEvaluation() {
        var bytecode = Bytecode()
        bytecode.appendOp(.pushInt)
        bytecode.appendInt(4)
        bytecode.appendOp(.pushInt)
        bytecode.appendInt(2)
        bytecode.appendOp(.multiply)
        bytecode.appendOp(.pushInt)
        bytecode.appendInt(8)
        bytecode.appendOp(.equal)
        let program = CompiledProgram(
            bytecode: bytecode,
            stringPool: [],
            symbolPool: [],
            typeTable: []
        )
        var interpreter = Interpreter()
        XCTAssertNoThrow(try interpreter.run(program))
        XCTAssertEqual(interpreter.valueStack.last?.boolValue, true)
    }

    func testMethodCallBridging() {
        var compiler = Compiler()
        compiler.emitPushString("hello")
        let symbol = compiler.emitSymbol("uppercased")
        compiler.emit(.callMethod)
        compiler.emitInt(symbol)
        compiler.emitInt(0)
        let program = compiler.finish()
        var interpreter = Interpreter()
        interpreter.allowedMethodNames = ["String": ["uppercased"]]
        XCTAssertNoThrow(try interpreter.run(program))
        XCTAssertEqual(interpreter.valueStack.last?.stringValue, "HELLO")
    }

    func testSwiftUIRendering() {
        #if canImport(SwiftUI)
        var compiler = Compiler()
        compiler.emitPushString("Works")
        let symbol = compiler.emitSymbol("Text")
        compiler.emit(.constructType)
        compiler.emitInt(symbol)
        compiler.emitInt(1)
        let program = compiler.finish()
        var interpreter = Interpreter()
        interpreter.allowedTypeNames = ["Text"]
        XCTAssertNoThrow(try interpreter.run(program))
        XCTAssertNotNil(interpreter.valueStack.last?.viewValue)
        #else
        XCTAssertTrue(true)
        #endif
    }

}
