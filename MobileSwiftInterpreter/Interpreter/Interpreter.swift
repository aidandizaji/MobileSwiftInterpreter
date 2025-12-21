#if canImport(SwiftUI)
import SwiftUI
#endif

//
//  Interpreter.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-18.
//

protocol InterpreterLogger {
    func log(_ message: String)
}

enum InterpreterRuntimeError: Error {
    case stackUnderflow
    case invalidSymbol(Int)
    case invalidStringIndex(Int)
    case invalidLocalSlot(Int)
    case divideByZero
    case bridgeNotAllowed(String)
    case invalidReturnValue
}

struct CallFrame {
    let returnPC: Int
    let stackBase: Int
    let localsIndex: Int
}

struct Interpreter {
    var pc: Int
    var valueStack: [InterpreterValue]
    var callStack: [CallFrame]
    var locals: [[InterpreterValue]]
    var stringPool: [String]
    var symbolPool: [String]
    var typeTable: [InterpreterType]
    var bytecode: Bytecode
    var logger: InterpreterLogger?
    var allowedTypeNames: Set<String>
    var allowedMethodNames: [String: Set<String>]
    var allowedFunctionNames: Set<String>

    init() {
        self.pc = 0
        self.valueStack = []
        self.callStack = []
        self.locals = []
        self.stringPool = []
        self.symbolPool = []
        self.typeTable = []
        self.bytecode = Bytecode()
        self.logger = nil
        self.allowedTypeNames = []
        self.allowedMethodNames = [:]
        self.allowedFunctionNames = []
    }

    mutating func run(_ program: CompiledProgram) throws {
        self.pc = 0
        self.valueStack = []
        self.callStack = []
        self.locals = [[]]
        self.stringPool = program.stringPool
        self.symbolPool = program.symbolPool
        self.typeTable = program.typeTable
        self.bytecode = program.bytecode

        while pc < bytecode.count {
            let op = nextOp()
            try execute(op)
        }
    }

    mutating func nextOp() -> Operation {
        let raw = bytecode.bytes[pc]
        pc += 1
        return Operation(rawValue: raw) ?? .returnValue
    }

    mutating func nextInt() -> Int {
        let end = pc + Bytecode.intByteWidth
        let slice = bytecode.bytes[pc..<end]
        pc = end
        var raw: Int64 = 0
        _ = withUnsafeMutableBytes(of: &raw) { buffer in
            for (index, byte) in slice.enumerated() {
                buffer[index] = byte
            }
        }
        return Int(Int64(littleEndian: raw))
    }

    mutating func nextBool() -> Bool {
        let raw = bytecode.bytes[pc]
        pc += 1
        return raw != 0
    }

    mutating func nextDouble() -> Double {
        let end = pc + Bytecode.doubleByteWidth
        let slice = bytecode.bytes[pc..<end]
        pc = end
        var raw: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &raw) { buffer in
            for (index, byte) in slice.enumerated() {
                buffer[index] = byte
            }
        }
        return Double(bitPattern: UInt64(littleEndian: raw))
    }

    mutating func nextSymbol() -> Int {
        return nextInt()
    }

    mutating func push(_ value: InterpreterValue) {
        valueStack.append(value)
    }

    mutating func pop() -> InterpreterValue? {
        guard !valueStack.isEmpty else {
            return nil
        }
        return valueStack.removeLast()
    }

    mutating func popValues(count: Int) throws -> [InterpreterValue] {
        guard count > 0 else {
            return []
        }
        var values: [InterpreterValue] = []
        for _ in 0..<count {
            guard let value = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            values.append(value)
        }
        return values.reversed()
    }

    mutating func execute(_ op: Operation) throws {
        switch op {
        case .pushInt:
            let value = nextInt()
            push(.nativeValue(value))
        case .pushBool:
            let value = nextBool()
            push(.nativeValue(value))
        case .pushDouble:
            let value = nextDouble()
            push(.nativeValue(value))
        case .pushString:
            let index = nextInt()
            guard stringPool.indices.contains(index) else {
                throw InterpreterRuntimeError.invalidStringIndex(index)
            }
            let value = stringPool[index]
            push(.nativeValue(value))
        case .add:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
                push(.nativeValue(lhsInt + rhsInt))
            } else if let rhsDouble = rhsValue.doubleValue, let lhsDouble = lhsValue.doubleValue {
                push(.nativeValue(lhsDouble + rhsDouble))
            } else {
                throw InterpreterRuntimeError.stackUnderflow
            }
        case .subtract:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
                push(.nativeValue(lhsInt - rhsInt))
            } else if let rhsDouble = rhsValue.doubleValue, let lhsDouble = lhsValue.doubleValue {
                push(.nativeValue(lhsDouble - rhsDouble))
            } else {
                throw InterpreterRuntimeError.stackUnderflow
            }
        case .multiply:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
                push(.nativeValue(lhsInt * rhsInt))
            } else if let rhsDouble = rhsValue.doubleValue, let lhsDouble = lhsValue.doubleValue {
                push(.nativeValue(lhsDouble * rhsDouble))
            } else {
                throw InterpreterRuntimeError.stackUnderflow
            }
        case .divide:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
                if rhsInt == 0 {
                    throw InterpreterRuntimeError.divideByZero
                }
                push(.nativeValue(lhsInt / rhsInt))
            } else if let rhsDouble = rhsValue.doubleValue, let lhsDouble = lhsValue.doubleValue {
                if rhsDouble == 0 {
                    throw InterpreterRuntimeError.divideByZero
                }
                push(.nativeValue(lhsDouble / rhsDouble))
            } else {
                throw InterpreterRuntimeError.stackUnderflow
            }
        case .lessThan:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
                push(.nativeValue(lhsInt < rhsInt))
            } else if let rhsDouble = rhsValue.doubleValue, let lhsDouble = lhsValue.doubleValue {
                push(.nativeValue(lhsDouble < rhsDouble))
            } else {
                throw InterpreterRuntimeError.stackUnderflow
            }
        case .equal:
            let rhs = pop()
            let lhs = pop()
            guard rhs != nil, lhs != nil else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            let result: Bool
            if let lhsInt = lhs?.intValue, let rhsInt = rhs?.intValue {
                result = lhsInt == rhsInt
            } else if let lhsDouble = lhs?.doubleValue, let rhsDouble = rhs?.doubleValue {
                result = lhsDouble == rhsDouble
            } else if let lhsBool = lhs?.boolValue, let rhsBool = rhs?.boolValue {
                result = lhsBool == rhsBool
            } else if let lhsString = lhs?.stringValue, let rhsString = rhs?.stringValue {
                result = lhsString == rhsString
            } else {
                result = false
            }
            push(.nativeValue(result))
        case .jump:
            let offset = nextInt()
            pc += offset
        case .jumpIfFalse:
            let offset = nextInt()
            guard let condition = pop()?.boolValue else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if !condition {
                pc += offset
            }
        case .loadLocal:
            let slot = nextInt()
            guard let frame = locals.last, slot < frame.count else {
                throw InterpreterRuntimeError.invalidLocalSlot(slot)
            }
            push(frame[slot])
        case .storeLocal:
            let slot = nextInt()
            guard let value = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if locals.isEmpty {
                locals.append([])
            }
            while locals[locals.count - 1].count <= slot {
                locals[locals.count - 1].append(.nativeValue(()))
            }
            locals[locals.count - 1][slot] = value
        case .callMethod:
            let symbol = nextSymbol()
            let argCount = nextInt()
            let arguments = try popValues(count: argCount)
            guard let base = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            let result = try evaluateMethodCall(base: base, symbol: symbol, arguments: arguments)
            push(result)
        case .callFunction:
            let symbol = nextSymbol()
            let argCount = nextInt()
            let arguments = try popValues(count: argCount)
            let result = try evaluateFunctionCall(symbol: symbol, arguments: arguments)
            push(result)
        case .getProperty:
            let symbol = nextSymbol()
            let propertyName = try symbolName(symbol)
            guard let base = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            switch base {
            case .customInstance(let instance):
                if let value = instance.fields[propertyName] {
                    push(value)
                } else {
                    throw InterpreterRuntimeError.invalidReturnValue
                }
            case .nativeValue:
                if let stringValue = base.stringValue,
                   allowedMethodNames["String"]?.contains(propertyName) == true,
                   propertyName == "count" {
                    push(.nativeValue(stringValue.count))
                } else {
                    throw InterpreterRuntimeError.invalidReturnValue
                }
            }
        case .constructType:
            let symbol = nextSymbol()
            let argCount = nextInt()
            let typeName = try symbolName(symbol)
            let arguments = try popValues(count: argCount)
            let value = try evaluateInitializer(typeName: typeName, arguments: arguments)
            push(value)
        case .returnValue:
            let returnValue = pop() ?? .nativeValue(())
            guard let frame = callStack.popLast() else {
                pc = bytecode.count
                push(returnValue)
                return
            }
            pc = frame.returnPC
            valueStack = Array(valueStack.prefix(frame.stackBase))
            if locals.indices.contains(frame.localsIndex) {
                locals = Array(locals.prefix(frame.localsIndex + 1))
            }
            push(returnValue)
        }
    }
}

extension Interpreter {
    func evaluateMethodCall(
        base: InterpreterValue,
        symbol: Int,
        arguments: [InterpreterValue]
    ) throws -> InterpreterValue {
        let name = try symbolName(symbol)
        guard isMethodAllowed(name, base: base) else {
            throw InterpreterRuntimeError.bridgeNotAllowed(name)
        }
        switch base {
        case .nativeValue(let value):
            if let stringValue = value as? String {
                switch name {
                case "uppercased":
                    return .nativeValue(stringValue.uppercased())
                case "lowercased":
                    return .nativeValue(stringValue.lowercased())
                case "count":
                    return .nativeValue(stringValue.count)
                default:
                    throw InterpreterRuntimeError.bridgeNotAllowed(name)
                }
            }
            if let intValue = value as? Int {
                switch name {
                case "description":
                    return .nativeValue(String(intValue))
                default:
                    throw InterpreterRuntimeError.bridgeNotAllowed(name)
                }
            }
            #if canImport(SwiftUI)
            if let view = value as? AnyView {
                switch name {
                case "padding":
                    if let amount = arguments.first?.intValue {
                        return .nativeValue(AnyView(view.padding(CGFloat(amount))))
                    }
                    return .nativeValue(AnyView(view.padding()))
                default:
                    throw InterpreterRuntimeError.bridgeNotAllowed(name)
                }
            }
            #endif
            throw InterpreterRuntimeError.invalidReturnValue
        case .customInstance(let instance):
            if let value = instance.fields[name] {
                return value
            }
            throw InterpreterRuntimeError.invalidReturnValue
        }
    }

    func evaluateInitializer(
        typeName: String,
        arguments: [InterpreterValue]
    ) throws -> InterpreterValue {
        guard allowedTypeNames.contains(typeName) else {
            throw InterpreterRuntimeError.bridgeNotAllowed(typeName)
        }
        #if canImport(SwiftUI)
        if typeName == "ClosedRange" {
            let lower = arguments.first?.doubleValue ?? 0
            let upper = arguments.dropFirst().first?.doubleValue ?? lower
            return .nativeValue(lower...upper)
        }
        if typeName == "Text" {
            let content = arguments.first?.stringValue ?? ""
            let view = AnyView(Text(content))
            return .nativeValue(view)
        }
        if typeName == "EmptyView" {
            return .nativeValue(AnyView(EmptyView()))
        }
        if typeName == "Spacer" {
            return .nativeValue(AnyView(Spacer()))
        }
        if typeName == "VStack" {
            let views = arguments.compactMap { $0.viewValue }
            let stack = AnyView(VStack {
                ForEach(Array(views.enumerated()), id: \.offset) { element in
                    element.element
                }
            })
            return .nativeValue(stack)
        }
        if typeName == "HStack" {
            let views = arguments.compactMap { $0.viewValue }
            let stack = AnyView(HStack {
                ForEach(Array(views.enumerated()), id: \.offset) { element in
                    element.element
                }
            })
            return .nativeValue(stack)
        }
        if typeName == "Rectangle" {
            return .nativeValue(AnyView(Rectangle()))
        }
        if typeName == "Circle" {
            return .nativeValue(AnyView(Circle()))
        }
        if typeName == "Button" {
            let views = arguments.compactMap { $0.viewValue }
            if let title = arguments.first?.stringValue {
                return .nativeValue(AnyView(Button(title) {}))
            }
            if !views.isEmpty {
                let label: AnyView
                if views.count == 1 {
                    label = views[0]
                } else {
                    label = AnyView(VStack {
                        ForEach(Array(views.enumerated()), id: \.offset) { element in
                            element.element
                        }
                    })
                }
                return .nativeValue(AnyView(Button(action: {}) { label }))
            }
            return .nativeValue(AnyView(Button("Button") {}))
        }
        if typeName == "Slider" {
            let value = arguments.first?.doubleValue ?? 0
            var minValue: Double = 0
            var maxValue: Double = 1
            if let range = arguments.dropFirst().first?.doubleRangeValue {
                minValue = range.lowerBound
                maxValue = range.upperBound
            } else if arguments.count == 2 {
                maxValue = arguments[1].doubleValue ?? 1
            } else if arguments.count >= 3 {
                minValue = arguments[1].doubleValue ?? 0
                maxValue = arguments[2].doubleValue ?? 1
            }
            if maxValue <= minValue {
                maxValue = minValue + 1
            }
            let clampedValue = Swift.min(Swift.max(value, minValue), maxValue)
            let slider = InteractiveSlider(initialValue: clampedValue, range: minValue...maxValue)
            return .nativeValue(AnyView(slider))
        }
        if typeName == "Toggle" {
            let views = arguments.compactMap { $0.viewValue }
            let labelView = stackedView(from: views)
            let isOn = arguments.first(where: { $0.boolValue != nil })?.boolValue ?? false
            if let labelView = labelView {
                return .nativeValue(AnyView(InteractiveToggle(labelView: labelView, initialValue: isOn)))
            }
            let label = arguments.first?.stringValue ?? "Toggle"
            return .nativeValue(AnyView(InteractiveToggle(label: label, initialValue: isOn)))
        }
        if typeName == "TextField" {
            let placeholder = arguments.first?.stringValue ?? "Text"
            let initialValue = arguments.dropFirst().first?.stringValue ?? ""
            let field = InteractiveTextField(placeholder: placeholder, initialValue: initialValue)
            return .nativeValue(AnyView(field))
        }
        if typeName == "Stepper" {
            let views = arguments.compactMap { $0.viewValue }
            let labelView = stackedView(from: views)
            let value = arguments.first(where: { $0.intValue != nil })?.intValue ?? 0
            var minValue = 0
            var maxValue = 10
            if let range = arguments.last?.doubleRangeValue {
                minValue = Int(range.lowerBound)
                maxValue = Int(range.upperBound)
            } else if arguments.count == 3 {
                maxValue = arguments[2].intValue ?? maxValue
            } else if arguments.count >= 4 {
                minValue = arguments[2].intValue ?? minValue
                maxValue = arguments[3].intValue ?? maxValue
            }
            if maxValue <= minValue {
                maxValue = minValue + 1
            }
            if let labelView = labelView {
                let stepper = InteractiveStepper(
                    labelView: labelView,
                    initialValue: value,
                    range: minValue...maxValue
                )
                return .nativeValue(AnyView(stepper))
            }
            let label = arguments.first?.stringValue ?? "Stepper"
            let stepper = InteractiveStepper(label: label, initialValue: value, range: minValue...maxValue)
            return .nativeValue(AnyView(stepper))
        }
        #endif
        let instance = buildCustomInstance(typeName: typeName, arguments: arguments)
        return .customInstance(instance)
    }

    #if canImport(SwiftUI)
    private func stackedView(from views: [AnyView]) -> AnyView? {
        guard !views.isEmpty else {
            return nil
        }
        if views.count == 1 {
            return views[0]
        }
        return AnyView(VStack {
            ForEach(Array(views.enumerated()), id: \.offset) { element in
                element.element
            }
        })
    }
    #endif

    func evaluateFunctionCall(
        symbol: Int,
        arguments: [InterpreterValue]
    ) throws -> InterpreterValue {
        let name = try symbolName(symbol)
        guard allowedFunctionNames.contains(name) else {
            throw InterpreterRuntimeError.bridgeNotAllowed(name)
        }
        switch name {
        case "print":
            let message = arguments.map { value in
                if let stringValue = value.stringValue {
                    return stringValue
                }
                if let intValue = value.intValue {
                    return String(intValue)
                }
                if let boolValue = value.boolValue {
                    return String(boolValue)
                }
                return ""
            }.joined(separator: " ")
            logger?.log(message)
            return .nativeValue(())
        default:
            throw InterpreterRuntimeError.bridgeNotAllowed(name)
        }
    }

    func buildCustomInstance(typeName: String, arguments: [InterpreterValue]) -> CustomInstance {
        if let type = typeTable.first(where: { $0.name == typeName }) {
            var fields: [String: InterpreterValue] = [:]
            for (index, name) in type.fieldNames.enumerated() {
                if index < arguments.count {
                    fields[name] = arguments[index]
                }
            }
            return CustomInstance(typeName: typeName, fields: fields)
        }
        return CustomInstance(typeName: typeName, fields: [:])
    }

    private func symbolName(_ id: Int) throws -> String {
        guard symbolPool.indices.contains(id) else {
            throw InterpreterRuntimeError.invalidSymbol(id)
        }
        return symbolPool[id]
    }

    private func isMethodAllowed(_ method: String, base: InterpreterValue) -> Bool {
        let typeKey: String
        switch base {
        case .nativeValue(let value):
            if value is String {
                typeKey = "String"
            } else if value is Int {
                typeKey = "Int"
            } else {
                #if canImport(SwiftUI)
                if value is AnyView {
                    typeKey = "AnyView"
                } else {
                    typeKey = "Native"
                }
                #else
                typeKey = "Native"
                #endif
            }
        case .customInstance(let instance):
            typeKey = instance.typeName
        }
        return allowedMethodNames[typeKey]?.contains(method) ?? false
    }
}
