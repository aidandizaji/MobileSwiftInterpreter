#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
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
    var stateStore: StateStore?
    var actionPool: [ActionDescriptor]

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
        self.stateStore = nil
        self.actionPool = []
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
        self.actionPool = program.actionPool

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
        case .pushNil:
            push(.nativeValue(()))
        case .pushString:
            let index = nextInt()
            guard stringPool.indices.contains(index) else {
                throw InterpreterRuntimeError.invalidStringIndex(index)
            }
            let value = stringPool[index]
            push(.nativeValue(value))
        case .loadState:
            let symbol = nextSymbol()
            let name = try symbolName(symbol)
            if let stateStore = stateStore {
                push(stateStore.value(for: name))
            } else {
                push(.nativeValue(()))
            }
        case .pushBinding:
            let symbol = nextSymbol()
            let name = try symbolName(symbol)
            if let stateStore = stateStore {
                let binding = AnyBinding(
                    get: { stateStore.value(for: name) },
                    set: { stateStore.setValue($0, for: name) }
                )
                push(.nativeValue(binding))
            } else {
                push(.nativeValue(()))
            }
        case .pushAction:
            let index = nextInt()
            guard actionPool.indices.contains(index) else {
                throw InterpreterRuntimeError.invalidSymbol(index)
            }
            let descriptor = actionPool[index]
            if let stateStore = stateStore {
                let handler = ActionHandler {
                    stateStore.setValue(descriptor.value, for: descriptor.stateName)
                }
                push(.nativeValue(handler))
            } else {
                push(.nativeValue(()))
            }
        case .add:
            guard let rhsValue = pop(), let lhsValue = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if let lhsString = lhsValue.stringValue ?? stringify(lhsValue),
               let rhsString = rhsValue.stringValue ?? stringify(rhsValue),
               lhsValue.stringValue != nil || rhsValue.stringValue != nil {
                push(.nativeValue(lhsString + rhsString))
            } else if let rhsInt = rhsValue.intValue, let lhsInt = lhsValue.intValue {
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
        case .coalesce:
            guard let rhs = pop(), let lhs = pop() else {
                throw InterpreterRuntimeError.stackUnderflow
            }
            if case .nativeValue(let value) = lhs, value is Void {
                push(rhs)
            } else {
                push(lhs)
            }
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
    private func stringify(_ value: InterpreterValue) -> String? {
        if case .nativeValue(let raw) = value, raw is Void {
            return ""
        }
        if let stringValue = value.stringValue {
            return stringValue
        }
        if let intValue = value.intValue {
            return String(intValue)
        }
        if let doubleValue = value.doubleValue {
            return String(doubleValue)
        }
        if let boolValue = value.boolValue {
            return String(boolValue)
        }
        return nil
    }

    private func stringBinding(from binding: AnyBinding) -> Binding<String> {
        Binding(
            get: { binding.get().stringValue ?? "" },
            set: { binding.set(.nativeValue($0)) }
        )
    }

    private func boolBinding(from binding: AnyBinding) -> Binding<Bool> {
        Binding(
            get: { binding.get().boolValue ?? false },
            set: { binding.set(.nativeValue($0)) }
        )
    }

    private func doubleBinding(from binding: AnyBinding) -> Binding<Double> {
        Binding(
            get: { binding.get().doubleValue ?? 0 },
            set: { binding.set(.nativeValue($0)) }
        )
    }

    private func intBinding(from binding: AnyBinding) -> Binding<Int> {
        Binding(
            get: { binding.get().intValue ?? 0 },
            set: { binding.set(.nativeValue($0)) }
        )
    }

    private func color(from value: InterpreterValue) -> Color? {
        if let stringValue = value.stringValue {
            return color(fromName: stringValue)
        }
        return nil
    }

    private func color(fromName name: String) -> Color? {
        switch name {
        case "systemGray6":
            return Color(UIColor.systemGray6)
        case "systemGray5":
            return Color(UIColor.systemGray5)
        case "systemGray4":
            return Color(UIColor.systemGray4)
        case "blue":
            return Color.blue
        case "white":
            return Color.white
        case "primary":
            return Color.primary
        case "secondary":
            return Color.secondary
        default:
            return nil
        }
    }

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
                case "background":
                    if let colorValue = arguments.first {
                        if let color = color(from: colorValue) {
                            return .nativeValue(AnyView(view.background(color)))
                        }
                        if case .nativeValue(let raw) = colorValue, let color = raw as? Color {
                            return .nativeValue(AnyView(view.background(color)))
                        }
                    }
                    if let backgroundView = arguments.first?.viewValue {
                        return .nativeValue(AnyView(view.background(backgroundView)))
                    }
                    return .nativeValue(view)
                case "cornerRadius":
                    if let radius = arguments.first?.doubleValue {
                        return .nativeValue(AnyView(view.cornerRadius(radius)))
                    }
                    return .nativeValue(view)
                case "padding":
                    if let amount = arguments.first?.intValue {
                        return .nativeValue(AnyView(view.padding(CGFloat(amount))))
                    }
                    return .nativeValue(AnyView(view.padding()))
                case "foregroundColor":
                    if let colorValue = arguments.first {
                        if let color = color(from: colorValue) {
                            return .nativeValue(AnyView(view.foregroundColor(color)))
                        }
                        if case .nativeValue(let raw) = colorValue, let color = raw as? Color {
                            return .nativeValue(AnyView(view.foregroundColor(color)))
                        }
                    }
                    return .nativeValue(view)
                case "frame":
                    if let widthValue = arguments.first {
                        if widthValue.stringValue == "infinity" {
                            return .nativeValue(AnyView(view.frame(maxWidth: .infinity)))
                        }
                        if let width = widthValue.doubleValue {
                            return .nativeValue(AnyView(view.frame(width: width)))
                        }
                    }
                    return .nativeValue(view)
                case "keyboardType":
                    return .nativeValue(view)
                case "onTapGesture":
                    return .nativeValue(AnyView(view.onTapGesture {}))
                case "navigationTitle":
                    let title = arguments.first?.stringValue ?? ""
                    return .nativeValue(AnyView(view.navigationTitle(title)))
                case "font":
                    return .nativeValue(view)
                case "fontWeight":
                    return .nativeValue(view)
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
        if typeName == "Double" {
            if let value = arguments.first?.doubleValue {
                return .nativeValue(value)
            }
            if let stringValue = arguments.first?.stringValue,
               let parsed = Double(stringValue) {
                return .nativeValue(parsed)
            }
            return .nativeValue(())
        }
        if typeName == "ClosedRange" {
            let lower = arguments.first?.doubleValue ?? 0
            let upper = arguments.dropFirst().first?.doubleValue ?? lower
            return .nativeValue(lower...upper)
        }
        if typeName == "Color" {
            if let stringValue = arguments.first?.stringValue,
               let color = color(fromName: stringValue) {
                return .nativeValue(color)
            }
            return .nativeValue(Color.clear)
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
        if typeName == "List" {
            let views = arguments.compactMap { $0.viewValue }
            let list = AnyView(List {
                ForEach(Array(views.enumerated()), id: \.offset) { element in
                    element.element
                }
            })
            return .nativeValue(list)
        }
        if typeName == "NavigationStack" {
            let views = arguments.compactMap { $0.viewValue }
            let content = stackedView(from: views) ?? AnyView(EmptyView())
            return .nativeValue(AnyView(NavigationStack { content }))
        }
        if typeName == "NavigationLink" {
            let views = arguments.compactMap { $0.viewValue }
            let destination = views.first ?? AnyView(EmptyView())
            let labelViews = Array(views.dropFirst())
            let label = stackedView(from: labelViews) ?? AnyView(Text("Details"))
            let link = AnyView(NavigationLink(destination: destination) { label })
            return .nativeValue(link)
        }
        if typeName == "Rectangle" {
            return .nativeValue(AnyView(Rectangle()))
        }
        if typeName == "Circle" {
            return .nativeValue(AnyView(Circle()))
        }
        if typeName == "Button" {
            let views = arguments.compactMap { $0.viewValue }
            let action = arguments.first(where: { $0.actionValue != nil })?.actionValue
            if let title = arguments.first?.stringValue {
                if let action = action {
                    return .nativeValue(AnyView(Button(title) {
                        action.perform()
                    }))
                }
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
                if let action = action {
                    return .nativeValue(AnyView(Button(action: {
                        action.perform()
                    }) { label }))
                }
                return .nativeValue(AnyView(Button(action: {}) { label }))
            }
            if let action = action {
                return .nativeValue(AnyView(Button("Button") {
                    action.perform()
                }))
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
            if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                let slider = Slider(
                    value: doubleBinding(from: binding),
                    in: minValue...maxValue
                )
                return .nativeValue(AnyView(slider))
            } else {
                let slider = InteractiveSlider(initialValue: clampedValue, range: minValue...maxValue)
                return .nativeValue(AnyView(slider))
            }
        }
        if typeName == "Toggle" {
            let views = arguments.compactMap { $0.viewValue }
            let labelView = stackedView(from: views)
            let isOn = arguments.first(where: { $0.boolValue != nil })?.boolValue ?? false
            if let labelView = labelView {
                if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                    let toggle = Toggle(isOn: boolBinding(from: binding)) {
                        labelView
                    }
                    return .nativeValue(AnyView(toggle))
                }
                return .nativeValue(AnyView(InteractiveToggle(labelView: labelView, initialValue: isOn)))
            }
            let label = arguments.first?.stringValue ?? "Toggle"
            if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                return .nativeValue(AnyView(Toggle(label, isOn: boolBinding(from: binding))))
            }
            return .nativeValue(AnyView(InteractiveToggle(label: label, initialValue: isOn)))
        }
        if typeName == "TextField" {
            let placeholder = arguments.first?.stringValue ?? "Text"
            if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                let field = TextField(placeholder, text: stringBinding(from: binding))
                    .textFieldStyle(.roundedBorder)
                return .nativeValue(AnyView(field))
            }
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
                if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                    let stepper = Stepper(value: intBinding(from: binding), in: minValue...maxValue) {
                        labelView
                    }
                    return .nativeValue(AnyView(stepper))
                }
                let stepper = InteractiveStepper(
                    labelView: labelView,
                    initialValue: value,
                    range: minValue...maxValue
                )
                return .nativeValue(AnyView(stepper))
            }
            let label = arguments.first?.stringValue ?? "Stepper"
            if let binding = arguments.first(where: { $0.bindingValue != nil })?.bindingValue {
                let stepper = Stepper(label, value: intBinding(from: binding), in: minValue...maxValue)
                return .nativeValue(AnyView(stepper))
            }
            let stepper = InteractiveStepper(label: label, initialValue: value, range: minValue...maxValue)
            return .nativeValue(AnyView(stepper))
        }
        if typeName == "Divider" {
            return .nativeValue(AnyView(Divider()))
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
