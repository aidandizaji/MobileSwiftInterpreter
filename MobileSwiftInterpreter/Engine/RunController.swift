//
//  RunController.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation
import SwiftUI

enum RunControllerError: Error {
    case timeout
    case cancelled
}

struct RunController {
    let engine: EngineFacade
    let timeoutNanoseconds: UInt64

    init(engine: EngineFacade = EngineFacade(), timeoutMilliseconds: UInt64 = 250) {
        self.engine = engine
        self.timeoutNanoseconds = timeoutMilliseconds * 1_000_000
    }

    func run(source: String, logBuffer: LogBuffer, stateStore: StateStore?) async -> RunResult {
        do {
            if Task.isCancelled {
                throw RunControllerError.cancelled
            }
            let program = try await Task.detached(priority: .userInitiated) {
                // Engine hook: SwiftSyntax parse + compile to bytecode.
                try engine.compile(source: source)
            }.value
            if Task.isCancelled {
                throw RunControllerError.cancelled
            }

            let value = try await withTimeout {
                // Engine hook: interpret bytecode into a value.
                try engine.run(program: program, logBuffer: logBuffer, stateStore: stateStore)
            }
            if Task.isCancelled {
                throw RunControllerError.cancelled
            }

            // Engine hook: convert InterpreterValue into AnyView.
            let view = try engine.renderRootView(result: value)
            return .success(view: view, program: program)
        } catch is CancellationError {
            return .cancelled
        } catch let error as RunControllerError {
            let diagnostics = EngineErrorAdapter.diagnostics(from: map(error))
            return .failure(diagnostics: diagnostics)
        } catch {
            let diagnostics = EngineErrorAdapter.diagnostics(from: error)
            return .failure(diagnostics: diagnostics)
        }
    }

    private func withTimeout<T>(
        operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(priority: .userInitiated) {
                try operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw RunControllerError.timeout
            }
            guard let result = try await group.next() else {
                throw RunControllerError.cancelled
            }
            group.cancelAll()
            return result
        }
    }

    private func map(_ error: RunControllerError) -> EngineError {
        switch error {
        case .timeout:
            return .timeout
        case .cancelled:
            return .cancelled
        }
    }
}
