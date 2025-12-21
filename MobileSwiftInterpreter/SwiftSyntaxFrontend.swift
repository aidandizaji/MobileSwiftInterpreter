//
//  SwiftSyntaxFrontend.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

#if canImport(SwiftParser) && canImport(SwiftSyntax) && canImport(SwiftOperators)
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
    mutating func compileExpression(_ expr: ExprSyntax) {
        if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
            let value = Int(intLiteral.literal.text) ?? 0
            emitPushInt(value)
            return
        }
        if let ifExpr = expr.as(IfExprSyntax.self) {
            compile(ifExpr: ifExpr)
            return
        }
        if let boolLiteral = expr.as(BooleanLiteralExprSyntax.self) {
            emitPushBool(boolLiteral.literal.tokenKind == .keyword(.true))
            return
        }
        if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
            let value = stringLiteral.representedLiteralValue ?? ""
            emitPushString(value)
            return
        }
        if let identifier = expr.as(IdentifierExprSyntax.self) {
            let name = identifier.identifier.text
            if let slot = localTable[name] {
                emit(.loadLocal)
                emitInt(slot)
                return
            }
        }
        if let infix = expr.as(InfixOperatorExprSyntax.self) {
            compileInfix(infix)
            return
        }
        if let call = expr.as(FunctionCallExprSyntax.self) {
            compile(call: call)
            return
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            compile(member: member)
            return
        }
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
            compileExpression(expr)
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
                compileExpression(value)
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
                compileExpression(initializer.value)
                emit(.storeLocal)
                emitInt(slot)
            }
        }
    }

    private mutating func compile(ifExpr: IfExprSyntax) {
        guard let condition = ifExpr.conditions.first?.condition.as(ExprSyntax.self) else {
            return
        }
        compileExpression(condition)
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
        compileExpression(condition)
        let exitJump = emitJump(.jumpIfFalse)
        for item in whileStmt.body.statements {
            compileStatement(item)
        }
        let backOffsetLocation = emitJump(.jump)
        patchJump(at: backOffsetLocation, to: loopStart)
        let loopEnd = bytecode.count
        patchJump(at: exitJump, to: loopEnd)
    }

    private mutating func compileInfix(_ expr: InfixOperatorExprSyntax) {
        let opToken = expr.operator.as(BinaryOperatorExprSyntax.self)?.operator.text ?? ""
        if opToken == "&&" {
            compileExpression(expr.leftOperand)
            let falseJump = emitJump(.jumpIfFalse)
            compileExpression(expr.rightOperand)
            let endJump = emitJump(.jump)
            let falseTarget = bytecode.count
            patchJump(at: falseJump, to: falseTarget)
            emitPushBool(false)
            let endTarget = bytecode.count
            patchJump(at: endJump, to: endTarget)
            return
        }
        if opToken == "||" {
            compileExpression(expr.leftOperand)
            let rightJump = emitJump(.jumpIfFalse)
            emitPushBool(true)
            let endJump = emitJump(.jump)
            let rightTarget = bytecode.count
            patchJump(at: rightJump, to: rightTarget)
            compileExpression(expr.rightOperand)
            let endTarget = bytecode.count
            patchJump(at: endJump, to: endTarget)
            return
        }
        compileExpression(expr.leftOperand)
        compileExpression(expr.rightOperand)
        switch opToken {
        case "+":
            emit(.add)
        case "-":
            emit(.subtract)
        case "*":
            emit(.multiply)
        case "/":
            emit(.divide)
        case "<":
            emit(.lessThan)
        case "==":
            emit(.equal)
        default:
            break
        }
    }

    private mutating func compile(call: FunctionCallExprSyntax) {
        let arguments = call.arguments.map { $0.expression }
        if let identifier = call.calledExpression.as(IdentifierExprSyntax.self),
           let closure = call.trailingClosure {
            let name = identifier.identifier.text
            if name == "VStack" || name == "HStack" {
                let count = compile(closure: closure)
                let symbol = emitSymbol(name)
                emit(.constructType)
                emitInt(symbol)
                emitInt(count)
                return
            }
        }
        if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else {
                return
            }
            compileExpression(base)
            for argument in arguments {
                compileExpression(argument)
            }
            let symbol = emitSymbol(member.declName.baseName.text)
            emit(.callMethod)
            emitInt(symbol)
            emitInt(arguments.count)
            return
        }
        if let identifier = call.calledExpression.as(IdentifierExprSyntax.self) {
            let name = identifier.identifier.text
            for argument in arguments {
                compileExpression(argument)
            }
            let symbol = emitSymbol(name)
            if name.first?.isUppercase == true {
                emit(.constructType)
            } else {
                emit(.callFunction)
            }
            emitInt(symbol)
            emitInt(arguments.count)
            return
        }
    }

    private mutating func compile(member: MemberAccessExprSyntax) {
        guard let base = member.base else {
            return
        }
        compileExpression(base)
        let symbol = emitSymbol(member.declName.baseName.text)
        emit(.getProperty)
        emitInt(symbol)
    }

    private mutating func compile(closure: ClosureExprSyntax) -> Int {
        var count = 0
        for item in closure.statements {
            compileStatement(item)
            count += 1
        }
        return count
    }
}
#endif
