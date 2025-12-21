//
//  SwiftSyntaxFrontend.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

#if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
import Foundation
import SwiftParser
import SwiftSyntax
import SwiftOperators

struct SwiftSyntaxFrontend {
    func compile(source: String) throws -> CompiledProgram {
        let syntax = Parser.parse(source: source)
        let foldedSyntax = try OperatorTable.standardOperators.foldAll(syntax)
        var compiler = Compiler()
        guard let folded = foldedSyntax.as(SourceFileSyntax.self) else {
            return compiler.finish()
        }
        for item in folded.statements {
            compiler.compileStatement(item)
        }
        return compiler.finish()
    }
}

extension Compiler {
    @discardableResult
    mutating func compileExpression(_ expr: ExprSyntax) -> Bool {
        if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
            let value = Int(intLiteral.literal.text) ?? 0
            emitPushInt(value)
            return true
        }
        if let floatLiteral = expr.as(FloatLiteralExprSyntax.self) {
            let value = Double(floatLiteral.literal.text) ?? 0
            emitPushDouble(value)
            return true
        }
        if let ifExpr = expr.as(IfExprSyntax.self) {
            compile(ifExpr: ifExpr)
            return false
        }
        if let boolLiteral = expr.as(BooleanLiteralExprSyntax.self) {
            emitPushBool(boolLiteral.literal.tokenKind == .keyword(.true))
            return true
        }
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            if let value = stringLiteral.representedLiteralValue {
                emitPushString(value)
                return true
            }
            var isFirst = true
            for segment in stringLiteral.segments {
                if let stringSegment = segment.as(StringSegmentSyntax.self) {
                    emitPushString(stringSegment.content.text)
                } else if let exprSegment = segment.as(ExpressionSegmentSyntax.self) {
                    if let firstExpr = exprSegment.expressions.first?.expression {
                        if !compileExpression(firstExpr) {
                            emitPushNil()
                        }
                    } else {
                        emitPushNil()
                    }
                } else {
                    emitPushString("")
                }
                if !isFirst {
                    emit(.add)
                }
                isFirst = false
            }
            return true
        }
        if let identifier = expr.as(IdentifierExprSyntax.self) {
            let name = identifier.identifier.text
            if let slot = localTable[name] {
                emit(.loadLocal)
                emitInt(slot)
                return true
            }
            if stateIdentifiers.contains(name) {
                let symbol = emitSymbol(name)
                emit(.loadState)
                emitInt(symbol)
                return true
            }
            if let literal = literalBindings[name] {
                emitLiteral(literal)
                return true
            }
            if let computed = computedProperties[name] {
                return compileExpression(computed)
            }
            emitPushNil()
            return true
        }
        if let infix = expr.as(InfixOperatorExprSyntax.self) {
            return compileInfix(infix)
        }
        if let ternary = expr.as(TernaryExprSyntax.self) {
            return compileTernary(ternary)
        }
        if let call = expr.as(FunctionCallExprSyntax.self) {
            return compile(call: call)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            return compile(member: member)
        }
        if let prefix = expr.as(PrefixOperatorExprSyntax.self) {
            return compile(prefix: prefix)
        }
        emitPushNil()
        return true
    }

    mutating func compileStatement(_ item: CodeBlockItemSyntax) {
        if let decl = item.item.as(DeclSyntax.self) {
            compileDeclaration(decl)
            return
        }
        if let stmt = item.item.as(StmtSyntax.self) {
            compileStatement(stmt)
            return
        }
        if let expr = item.item.as(ExprSyntax.self) {
            _ = compileExpression(expr)
            return
        }
    }

    mutating func compileStatement(_ stmt: StmtSyntax) {
        if let ifStmt = stmt.as(IfExprSyntax.self) {
            compile(ifExpr: ifStmt)
            return
        }
        if let whileStmt = stmt.as(WhileStmtSyntax.self) {
            compile(whileStmt: whileStmt)
            return
        }
        if let returnStmt = stmt.as(ReturnStmtSyntax.self) {
            if let value = returnStmt.expression {
                _ = compileExpression(value)
            } else {
                emitPushBool(false)
            }
            emit(.returnValue)
            return
        }
    }

    mutating func compileDeclaration(_ decl: DeclSyntax) {
        if let variable = decl.as(VariableDeclSyntax.self) {
            compile(variable: variable)
            return
        }
        if let structDecl = decl.as(StructDeclSyntax.self) {
            let fields = structDecl.memberBlock.members.compactMap { member -> String? in
                guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                      let binding = varDecl.bindings.first,
                      let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
                else {
                    return nil
                }
                return pattern.identifier.text
            }
            declareType(name: structDecl.name.text, fieldNames: fields)
            return
        }
    }

    private mutating func compile(variable: VariableDeclSyntax) {
        for binding in variable.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let name = pattern.identifier.text
            let slot = allocateLocal(name)
            if let initializer = binding.initializer {
                _ = compileExpression(initializer.value)
                emit(.storeLocal)
                emitInt(slot)
            }
        }
    }

    private mutating func compile(ifExpr: IfExprSyntax) {
        guard let condition = ifExpr.conditions.first?.condition.as(ExprSyntax.self) else {
            return
        }
        _ = compileExpression(condition)
        let jumpToElse = emitJump(.jumpIfFalse)
        for item in ifExpr.body.statements {
            compileStatement(item)
        }
        let jumpToEnd = emitJump(.jump)
        let elseTarget = bytecode.count
        patchJump(at: jumpToElse, to: elseTarget)
        if let elseBody = ifExpr.elseBody {
            compileElseBody(elseBody)
        }
        let endTarget = bytecode.count
        patchJump(at: jumpToEnd, to: endTarget)
    }

    private mutating func compileElseBody(_ elseBody: IfExprSyntax.ElseBody) {
        let syntax = Syntax(elseBody)
        if let block = syntax.as(CodeBlockSyntax.self) {
            for item in block.statements {
                compileStatement(item)
            }
            return
        }
        if let ifExpr = syntax.as(IfExprSyntax.self) {
            compile(ifExpr: ifExpr)
            return
        }
    }

    private mutating func compile(whileStmt: WhileStmtSyntax) {
        let loopStart = bytecode.count
        guard let condition = whileStmt.conditions.first?.condition.as(ExprSyntax.self) else {
            return
        }
        _ = compileExpression(condition)
        let exitJump = emitJump(.jumpIfFalse)
        for item in whileStmt.body.statements {
            compileStatement(item)
        }
        let backOffsetLocation = emitJump(.jump)
        patchJump(at: backOffsetLocation, to: loopStart)
        let loopEnd = bytecode.count
        patchJump(at: exitJump, to: loopEnd)
    }

    private mutating func compileInfix(_ expr: InfixOperatorExprSyntax) -> Bool {
        let opToken = expr.operator.as(BinaryOperatorExprSyntax.self)?.operator.text ?? ""
        if opToken == "&&" {
            _ = compileExpression(expr.leftOperand)
            let falseJump = emitJump(.jumpIfFalse)
            _ = compileExpression(expr.rightOperand)
            let endJump = emitJump(.jump)
            let falseTarget = bytecode.count
            patchJump(at: falseJump, to: falseTarget)
            emitPushBool(false)
            let endTarget = bytecode.count
            patchJump(at: endJump, to: endTarget)
            return true
        }
        if opToken == "||" {
            _ = compileExpression(expr.leftOperand)
            let rightJump = emitJump(.jumpIfFalse)
            emitPushBool(true)
            let endJump = emitJump(.jump)
            let rightTarget = bytecode.count
            patchJump(at: rightJump, to: rightTarget)
            _ = compileExpression(expr.rightOperand)
            let endTarget = bytecode.count
            patchJump(at: endJump, to: endTarget)
            return true
        }
        let lhsOk = compileExpression(expr.leftOperand)
        let rhsOk = compileExpression(expr.rightOperand)
        if !lhsOk {
            emitPushNil()
        }
        if !rhsOk {
            emitPushNil()
        }
        switch opToken {
        case "+":
            emit(.add)
            return true
        case "-":
            emit(.subtract)
            return true
        case "*":
            emit(.multiply)
            return true
        case "/":
            emit(.divide)
            return true
        case "<":
            emit(.lessThan)
            return true
        case "==":
            emit(.equal)
            return true
        case "??":
            emit(.coalesce)
            return true
        case "...":
            let symbol = emitSymbol("ClosedRange")
            emit(.constructType)
            emitInt(symbol)
            emitInt(2)
            return true
        default:
            return false
        }
    }

    private mutating func compile(call: FunctionCallExprSyntax) -> Bool {
        let arguments = call.arguments.map { $0.expression }
        if let identifier = call.calledExpression.as(IdentifierExprSyntax.self) {
            let name = identifier.identifier.text
            if let closure = call.trailingClosure,
               name == "VStack" || name == "HStack" {
                let count = compile(closure: closure)
                let symbol = emitSymbol(name)
                emit(.constructType)
                emitInt(symbol)
                emitInt(count)
                return true
            }
            if let closure = call.trailingClosure,
               name == "Toggle" || name == "Stepper" || name == "NavigationLink" || name == "NavigationStack" || name == "List" {
                let nonClosureArgs = arguments.filter { $0.as(ClosureExprSyntax.self) == nil }
                for argument in nonClosureArgs {
                    if !compileExpression(argument) {
                        emitPushNil()
                    }
                }
                let labelCount = compile(closure: closure)
                let symbol = emitSymbol(name)
                emit(.constructType)
                emitInt(symbol)
                emitInt(nonClosureArgs.count + labelCount)
                return true
            }
            if name == "Button" {
                var argCount = 0
                for argument in call.arguments {
                    if let closure = argument.expression.as(ClosureExprSyntax.self) {
                        if let descriptor = actionDescriptor(from: closure) {
                            emitPushAction(descriptor)
                            argCount += 1
                            continue
                        }
                    }
                    if !compileExpression(argument.expression) {
                        emitPushNil()
                    }
                    argCount += 1
                }
                if let label = call.trailingClosure {
                    argCount += compile(closure: label)
                }
                let symbol = emitSymbol(name)
                emit(.constructType)
                emitInt(symbol)
                emitInt(argCount)
                return true
            }
        }
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else {
                emitPushNil()
                return true
            }
            if !compileExpression(base) {
                emitPushNil()
            }
            for argument in arguments {
                if !compileExpression(argument) {
                    emitPushNil()
                }
            }
            let symbol = emitSymbol(member.declName.baseName.text)
            emit(.callMethod)
            emitInt(symbol)
            emitInt(arguments.count)
            return true
        }
        if let identifier = call.calledExpression.as(IdentifierExprSyntax.self) {
            let name = identifier.identifier.text
            for argument in arguments {
                if !compileExpression(argument) {
                    emitPushNil()
                }
            }
            let symbol = emitSymbol(name)
            if name.first?.isUppercase == true {
                emit(.constructType)
            } else {
                emit(.callFunction)
            }
            emitInt(symbol)
            emitInt(arguments.count)
            return true
        }
        emitPushNil()
        return true
    }

    private mutating func compile(member: MemberAccessExprSyntax) -> Bool {
        guard let base = member.base else {
            emitPushString(member.declName.baseName.text)
            return true
        }
        if let identifier = base.as(IdentifierExprSyntax.self),
           identifier.identifier.text == "Color" {
            emitPushString(member.declName.baseName.text)
            let symbol = emitSymbol("Color")
            emit(.constructType)
            emitInt(symbol)
            emitInt(1)
            return true
        }
        if !compileExpression(base) {
            emitPushNil()
        }
        let symbol = emitSymbol(member.declName.baseName.text)
        emit(.getProperty)
        emitInt(symbol)
        return true
    }

    private mutating func compile(closure: ClosureExprSyntax) -> Int {
        var count = 0
        for item in closure.statements {
            guard let expr = item.item.as(ExprSyntax.self) else {
                continue
            }
            if expr.as(IfExprSyntax.self) != nil {
                continue
            }
            if let call = expr.as(FunctionCallExprSyntax.self),
               let identifier = call.calledExpression.as(IdentifierExprSyntax.self),
               identifier.identifier.text == "ForEach" {
                count += compileForEach(call: call)
                continue
            }
            if !compileExpression(expr) {
                emitPushNil()
            }
            count += 1
        }
        return count
    }

    private mutating func compile(prefix: PrefixOperatorExprSyntax) -> Bool {
        let opToken = prefix.operator.text
        if opToken == "$" {
            if let identifier = prefix.expression.as(IdentifierExprSyntax.self) {
                let name = identifier.identifier.text
                if stateIdentifiers.contains(name) {
                    let symbol = emitSymbol(name)
                    emit(.pushBinding)
                    emitInt(symbol)
                    return true
                }
            }
            if !compileExpression(prefix.expression) {
                emitPushNil()
            }
            return true
        }
        if opToken == "-" {
            if !compileExpression(prefix.expression) {
                emitPushNil()
            }
            emitPushInt(-1)
            emit(.multiply)
            return true
        }
        emitPushNil()
        return true
    }

    private mutating func compileTernary(_ expr: TernaryExprSyntax) -> Bool {
        _ = compileExpression(expr.condition)
        let jumpToElse = emitJump(.jumpIfFalse)
        if !compileExpression(expr.thenExpression) {
            emitPushNil()
        }
        let jumpToEnd = emitJump(.jump)
        let elseTarget = bytecode.count
        patchJump(at: jumpToElse, to: elseTarget)
        if !compileExpression(expr.elseExpression) {
            emitPushNil()
        }
        let endTarget = bytecode.count
        patchJump(at: jumpToEnd, to: endTarget)
        return true
    }

    private mutating func compileForEach(call: FunctionCallExprSyntax) -> Int {
        guard let closure = call.trailingClosure else {
            return 0
        }
        guard let firstArg = call.arguments.first?.expression,
              let arrayExpr = firstArg.as(ArrayExprSyntax.self) else {
            return 0
        }
        let paramName = closureParameterName(from: closure) ?? "item"
        let previousBinding = literalBindings[paramName]
        var totalCount = 0
        for element in arrayExpr.elements {
            guard let value = literalValue(from: element.expression) else {
                continue
            }
            literalBindings[paramName] = value
            totalCount += compile(closure: closure)
        }
        literalBindings[paramName] = previousBinding
        return totalCount
    }

    private func closureParameterName(from closure: ClosureExprSyntax) -> String? {
        guard let signature = closure.signature,
              let clause = signature.parameterClause else {
            return nil
        }
        let text = clause.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let parts = trimmed.split(separator: ",")
        guard let first = parts.first else {
            return nil
        }
        let tokens = first.split(separator: " ")
        return tokens.last.map { String($0) }
    }

    private func literalValue(from expr: ExprSyntax) -> InterpreterValue? {
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
        if let identifier = expr.as(IdentifierExprSyntax.self),
           let literal = literalBindings[identifier.identifier.text] {
            return literal
        }
        return nil
    }

    private mutating func emitLiteral(_ value: InterpreterValue) {
        if let intValue = value.intValue {
            emitPushInt(intValue)
            return
        }
        if let doubleValue = value.doubleValue {
            emitPushDouble(doubleValue)
            return
        }
        if let stringValue = value.stringValue {
            emitPushString(stringValue)
            return
        }
        if let boolValue = value.boolValue {
            emitPushBool(boolValue)
            return
        }
        emitPushNil()
    }

    private func actionDescriptor(from closure: ClosureExprSyntax) -> ActionDescriptor? {
        guard let firstItem = closure.statements.first,
              let expr = firstItem.item.as(ExprSyntax.self),
              let infix = expr.as(InfixOperatorExprSyntax.self),
              let op = infix.operator.as(BinaryOperatorExprSyntax.self)?.operator.text,
              op == "="
        else {
            return nil
        }
        guard let lhs = infix.leftOperand.as(IdentifierExprSyntax.self) else {
            return nil
        }
        let name = lhs.identifier.text
        guard stateIdentifiers.contains(name) else {
            return nil
        }
        if let literal = literalValue(from: infix.rightOperand) {
            return ActionDescriptor(stateName: name, value: literal)
        }
        return nil
    }
}
#endif
