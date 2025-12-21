//
//  InterpretedView.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI

struct InterpretedView: View {
    let program: CompiledProgram
    let engine: EngineFacade
    @ObservedObject var stateStore: StateStore
    let logBuffer: LogBuffer

    var body: some View {
        renderedView
    }

    private var renderedView: AnyView {
        let value = try? engine.run(
            program: program,
            logBuffer: logBuffer,
            stateStore: stateStore
        )
        if let value = value, let view = try? engine.renderRootView(result: value) {
            return view
        }
        return AnyView(EmptyView())
    }
}
