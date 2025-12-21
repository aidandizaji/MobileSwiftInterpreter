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
        "Color",
        "Divider",
        "Double",
        "EmptyView",
        "HStack",
        "List",
        "NavigationLink",
        "NavigationStack",
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
        "AnyView": [
            "background",
            "cornerRadius",
            "font",
            "fontWeight",
            "foregroundColor",
            "frame",
            "keyboardType",
            "navigationTitle",
            "onTapGesture",
            "padding"
        ]
    ]

    let allowedFunctionNames: Set<String> = [
        "print"
    ]
}

struct EngineFacade {
    private let whitelist = BridgeWhitelist()

    func compile(source: String) throws -> CompiledProgram {
        #if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
        let sources = splitSources(source)
        let parsedFiles = sources.map { Parser.parse(source: $0) }

        #if canImport(SwiftDiagnostics) && canImport(SwiftParserDiagnostics)
        for (index, syntax) in parsedFiles.enumerated() {
            let diagnostics = ParseDiagnosticsGenerator.diagnostics(for: syntax)
            if !diagnostics.isEmpty {
                let converter = SourceLocationConverter(file: "AppView\(index).swift", tree: syntax)
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
        }
        #endif

        let foldedFiles = try parsedFiles.map { syntax in
            try OperatorTable.standardOperators.foldAll(syntax)
        }
        let sourceFiles = foldedFiles.compactMap { $0.as(SourceFileSyntax.self) }
        guard !sourceFiles.isEmpty else {
            throw EngineError.compile(
                message: "Failed to parse source files.",
                line: nil,
                column: nil
            )
        }

        guard let appInfo = AppViewExtractor.info(from: sourceFiles) else {
            throw EngineError.compile(
                message: "Missing entry point. Define struct AppView: View with a body.",
                line: nil,
                column: nil
            )
        }

        var compiler = Compiler()
        compiler.stateIdentifiers = appInfo.stateIdentifiers
        compiler.stateDefaults = appInfo.stateDefaults
        compiler.computedProperties = appInfo.computedProperties

        for file in sourceFiles {
            for item in file.statements {
                guard let decl = item.item.as(DeclSyntax.self),
                      let structDecl = decl.as(StructDeclSyntax.self),
                      structDecl.name.text != "AppView"
                else {
                    continue
                }
                compiler.compileDeclaration(decl)
            }
        }

        switch appInfo.body {
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

    func run(program: CompiledProgram, logBuffer: LogBuffer, stateStore: StateStore?) throws -> InterpreterValue {
        var interpreter = Interpreter()
        interpreter.logger = logBuffer
        interpreter.allowedTypeNames = whitelist.allowedTypeNames
        interpreter.allowedMethodNames = whitelist.allowedMethodNames
        interpreter.allowedFunctionNames = whitelist.allowedFunctionNames
        interpreter.stateStore = stateStore
        if let stateStore = stateStore {
            for (name, value) in program.stateDefaults {
                stateStore.setDefault(value, for: name)
            }
        }
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
    struct AppViewInfo {
        let body: Body
        let stateIdentifiers: Set<String>
        let stateDefaults: [String: InterpreterValue]
        let computedProperties: [String: ExprSyntax]
    }

    enum Body {
        case items(CodeBlockItemListSyntax)
        case expression(ExprSyntax)
    }

    static func info(from trees: [SourceFileSyntax]) -> AppViewInfo? {
        for tree in trees {
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
                var stateIdentifiers: Set<String> = []
                var stateDefaults: [String: InterpreterValue] = [:]
                var computedProperties: [String: ExprSyntax] = [:]
                for member in structDecl.memberBlock.members {
                    guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
                        continue
                    }
                    if hasAttribute(varDecl, named: "State") {
                        for binding in varDecl.bindings {
                            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                                continue
                            }
                            let name = pattern.identifier.text
                            stateIdentifiers.insert(name)
                            if let initializer = binding.initializer,
                               let literal = literalValue(from: initializer.value) {
                                stateDefaults[name] = literal
                            }
                        }
                    } else {
                        for binding in varDecl.bindings {
                            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                                continue
                            }
                            let name = pattern.identifier.text
                            if name == "body" {
                                continue
                            }
                            if let accessorBlock = binding.accessorBlock,
                               let expression = expression(from: accessorBlock) {
                                computedProperties[name] = expression
                            } else if let initializer = binding.initializer {
                                computedProperties[name] = initializer.value
                            }
                        }
                    }
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
                                        return AppViewInfo(
                                            body: .items(body),
                                            stateIdentifiers: stateIdentifiers,
                                            stateDefaults: stateDefaults,
                                            computedProperties: computedProperties
                                        )
                                    }
                                }
                            case .getter(let body):
                                return AppViewInfo(
                                    body: .items(body),
                                    stateIdentifiers: stateIdentifiers,
                                    stateDefaults: stateDefaults,
                                    computedProperties: computedProperties
                                )
                            @unknown default:
                                break
                            }
                        }
                        if let initializer = binding.initializer {
                            return AppViewInfo(
                                body: .expression(initializer.value),
                                stateIdentifiers: stateIdentifiers,
                                stateDefaults: stateDefaults,
                                computedProperties: computedProperties
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func hasAttribute(_ decl: VariableDeclSyntax, named name: String) -> Bool {
        let attributes = decl.attributes
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else {
                continue
            }
            if attr.attributeName.trimmedDescription == name {
                return true
            }
        }
        return false
    }

    private static func literalValue(from expr: ExprSyntax) -> InterpreterValue? {
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            return .nativeValue(stringLiteral.representedLiteralValue ?? "")
        }
        if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
            return .nativeValue(Int(intLiteral.literal.text) ?? 0)
        }
        if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
            return .nativeValue(Double(floatLiteral.literal.text) ?? 0)
        }
        if let boolLiteral = expr.as(BooleanLiteralExprSyntax.self) {
            return .nativeValue(boolLiteral.literal.tokenKind == .keyword(.true))
        }
        return nil
    }

    private static func expression(from accessor: AccessorBlockSyntax) -> ExprSyntax? {
        switch accessor.accessors {
        case .accessors(let accessorList):
            for accessorDecl in accessorList {
                if let body = accessorDecl.body {
                    if let expr = firstExpression(in: body.statements) {
                        return expr
                    }
                }
            }
        case .getter(let statements):
            return firstExpression(in: statements)
        @unknown default:
            break
        }
        return nil
    }

    private static func firstExpression(in statements: CodeBlockItemListSyntax) -> ExprSyntax? {
        for item in statements {
            if let returnStmt = item.item.as(ReturnStmtSyntax.self),
               let expr = returnStmt.expression {
                return expr
            }
            if let expr = item.item.as(ExprSyntax.self) {
                return expr
            }
        }
        return nil
    }
}
#endif

private func splitSources(_ source: String) -> [String] {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    var files: [String] = []
    var current: [String] = []
    for line in lines {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("// File:") ||
            line.trimmingCharacters(in: .whitespaces).hasPrefix("// --- File:") {
            if !current.isEmpty {
                files.append(current.joined(separator: "\n"))
                current = []
            }
        } else {
            current.append(String(line))
        }
    }
    if !current.isEmpty {
        files.append(current.joined(separator: "\n"))
    }
    return files.isEmpty ? [source] : files
}
