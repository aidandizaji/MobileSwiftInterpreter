//
//  EngineErrorAdapter.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation

enum EngineError: Error {
    case parse([Diagnostic])
    case compile(message: String, line: Int?, column: Int?)
    case runtime(message: String, pc: Int?)
    case bridge(message: String)
    case timeout
    case cancelled
}

struct EngineErrorAdapter {
    static func diagnostics(from error: Error) -> [Diagnostic] {
        if let engineError = error as? EngineError {
            switch engineError {
            case .parse(let diagnostics):
                return diagnostics
            case .compile(let message, let line, let column):
                return [Diagnostic(phase: .compile, severity: .error, message: message, line: line, column: column)]
            case .runtime(let message, let pc):
                let suffix = pc.map { " (pc: \($0))" } ?? ""
                return [Diagnostic(phase: .runtime, severity: .error, message: message + suffix)]
            case .bridge(let message):
                return [Diagnostic(phase: .bridge, severity: .error, message: message)]
            case .timeout:
                return [Diagnostic(phase: .runtime, severity: .error, message: "Execution timed out.")]
            case .cancelled:
                return []
            }
        }
        if let runtimeError = error as? InterpreterRuntimeError {
            let message: String
            let phase: EnginePhase
            switch runtimeError {
            case .stackUnderflow:
                message = "Stack underflow."
                phase = .runtime
            case .invalidSymbol(let id):
                message = "Invalid symbol id \(id)."
                phase = .runtime
            case .invalidStringIndex(let index):
                message = "Invalid string pool index \(index)."
                phase = .runtime
            case .invalidLocalSlot(let slot):
                message = "Invalid local slot \(slot)."
                phase = .runtime
            case .divideByZero:
                message = "Division by zero."
                phase = .runtime
            case .bridgeNotAllowed(let name):
                message = "API not allowed: \(name)."
                phase = .bridge
            case .invalidReturnValue:
                message = "Invalid return value."
                phase = .runtime
            }
            return [Diagnostic(phase: phase, severity: .error, message: message)]
        }
        return [Diagnostic(phase: .runtime, severity: .error, message: error.localizedDescription)]
    }
}
