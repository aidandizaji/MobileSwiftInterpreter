//
//  SwiftUIStubs.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

#if canImport(SwiftUI)
import SwiftUI

struct ViewStub: View {
    let program: CompiledProgram
    let makeInterpreter: () -> Interpreter

    var body: some View {
        var interpreter = makeInterpreter()
        do {
            try interpreter.run(program)
            if let view = interpreter.valueStack.last?.viewValue {
                return view
            }
            return AnyView(EmptyView())
        } catch {
            return AnyView(EmptyView())
        }
    }
}

struct ShapeStub: Shape {
    let program: CompiledProgram
    let makeInterpreter: () -> Interpreter

    func path(in rect: CGRect) -> Path {
        var interpreter = makeInterpreter()
        do {
            try interpreter.run(program)
            if let value = interpreter.valueStack.last {
                switch value {
                case .nativeValue(let native):
                    if let path = native as? Path {
                        return path
                    }
                    return Path()
                case .customInstance:
                    return Path()
                }
            }
            return Path()
        } catch {
            return Path()
        }
    }
}
#endif
