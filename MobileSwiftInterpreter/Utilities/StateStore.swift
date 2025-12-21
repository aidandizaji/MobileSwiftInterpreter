//
//  StateStore.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation
import SwiftUI

struct AnyBinding {
    let get: () -> InterpreterValue
    let set: (InterpreterValue) -> Void
}

struct ActionDescriptor {
    let stateName: String
    let value: InterpreterValue
}

struct ActionHandler {
    let perform: () -> Void
}

final class StateStore: ObservableObject {
    @Published private(set) var values: [String: InterpreterValue] = [:]

    func value(for name: String) -> InterpreterValue {
        values[name] ?? .nativeValue(())
    }

    func setValue(_ value: InterpreterValue, for name: String) {
        values[name] = value
    }

    func setDefault(_ value: InterpreterValue, for name: String) {
        if values[name] == nil {
            values[name] = value
        }
    }

    func reset() {
        values.removeAll()
    }
}
