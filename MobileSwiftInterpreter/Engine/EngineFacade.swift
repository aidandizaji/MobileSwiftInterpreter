//
//  EngineFacade.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation
import SwiftUI

#if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
import SwiftParser
import SwiftSyntax
import SwiftOperators
#endif

#if canImport(SwiftDiagnostics) && canImport(SwiftParserDiagnostics)
import SwiftDiagnostics
import SwiftParserDiagnostics
#endif

struct BridgeWhitelist {
    let allowedTypeNames: Set<String> = [
        "Button",
        "Circle",
        "ClosedRange",
        "EmptyView",
        "HStack",
        "Rectangle",
        "Slider",
        "Spacer",
        "Stepper",
        "Text",
        "TextField",
        "Toggle",
        "VStack"
    ]

    let allowedMethodNames: [String: Set<String>] = [
        "String": ["uppercased", "lowercased", "count"],
        "Int": ["description"],
        "AnyView": ["padding"]
    ]

    let allowedFunctionNames: Set<String> = [
        "print"
    ]
}

struct EngineFacade {
    private let whitelist = BridgeWhitelist()

    func compile(source: String) throws -> CompiledProgram {
        #if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
        let syntax = Parser.parse(source: source)

        #if canImport(SwiftDiagnostics) && canImport(SwiftParserDiagnostics)
        let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: syntax)
        if !diagnostics.isEmpty {
            let converter = SourceLocationConverter(file: "AppView.swift", tree: syntax)
            let mapped = diagnostics.map { diagnostic in
                let location = converter.location(for: diagnostic.position)
                return Diagnostic(
                    phase: .parse,
                    severity: .error,
                    message: String(describing: diagnostic.message),
                    line: location.line,
                    column: location.column
                )
            }
            throw EngineError.parse(mapped)
        }
        #endif

        let foldedSyntax = try OperatorTable.standardOperators.foldAll(syntax)
        guard let folded = foldedSyntax.as(SourceFileSyntax.self) else {
            throw EngineError.compile(
                message: "Failed to parse source file.",
                line: nil,
                column: nil
            )
        }
        guard let body = AppViewExtractor.body(from: folded) else {
            throw EngineError.compile(
                message: "Missing entry point. Define struct AppView: View with a body.",
                line: nil,
                column: nil
            )
        }
        var compiler = Compiler()
        switch body {
        case .items(let items):
            for item in items {
                compiler.compileStatement(item)
            }
        case .expression(let expr):
            compiler.compileExpression(expr)
        }
        return compiler.finish()
        #else
        throw EngineError.compile(
            message: "SwiftSyntax is not available in this build.",
            line: nil,
            column: nil
        )
        #endif
    }

    func run(program: CompiledProgram, logBuffer: LogBuffer) throws -> InterpreterValue {
        var interpreter = Interpreter()
        interpreter.logger = logBuffer
        interpreter.allowedTypeNames = whitelist.allowedTypeNames
        interpreter.allowedMethodNames = whitelist.allowedMethodNames
        interpreter.allowedFunctionNames = whitelist.allowedFunctionNames
        do {
            try interpreter.run(program)
            guard let result = interpreter.valueStack.last else {
                throw EngineError.runtime(message: "Program did not return a value.", pc: interpreter.pc)
            }
            return result
        } catch let error as InterpreterRuntimeError {
            switch error {
            case .bridgeNotAllowed(let name):
                throw EngineError.bridge(message: "API not allowed: \(name).")
            default:
                throw EngineError.runtime(message: "\(error)", pc: interpreter.pc)
            }
        }
    }

    func renderRootView(result: InterpreterValue) throws -> AnyView {
        if let view = result.viewValue {
            return view
        }
        throw EngineError.runtime(message: "Program did not return a View.", pc: nil)
    }
}

#if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
private enum AppViewExtractor {
    enum Body {
        case items(CodeBlockItemListSyntax)
        case expression(ExprSyntax)
    }

    static func body(from tree: SourceFileSyntax) -> Body? {
        for item in tree.statements {
            guard let decl = item.item.as(DeclSyntax.self) else {
                continue
            }
            guard let structDecl = decl.as(StructDeclSyntax.self) else {
                continue
            }
            guard structDecl.name.text == "AppView" else {
                continue
            }
            for member in structDecl.memberBlock.members {
                guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                    continue
                }
                for binding in varDecl.bindings {
                    guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                          pattern.identifier.text == "body"
                    else {
                        continue
                    }
                    if let accessorBlock = binding.accessorBlock {
                        switch accessorBlock.accessors {
                        case .accessors(let accessorList):
                            for accessor in accessorList {
                                if let body = accessor.body?.statements {
                                    return .items(body)
                                }
                            }
                        case .getter(let body):
                            return .items(body)
                        @unknown default:
                            break
                        }
                    }
                    if let initializer = binding.initializer {
                        return .expression(initializer.value)
                    }
                }
            }
        }
        return nil
    }
}
#endif
