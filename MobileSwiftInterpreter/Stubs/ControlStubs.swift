//
//  ControlStubs.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

#if canImport(SwiftUI)
import SwiftUI

struct InteractiveSlider: View {
    let range: ClosedRange<Double>
    @State private var value: Double

    init(initialValue: Double, range: ClosedRange<Double>) {
        self.range = range
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        Slider(value: $value, in: range)
    }
}

struct InteractiveToggle: View {
    let label: String?
    let labelView: AnyView?
    @State private var isOn: Bool

    init(label: String, initialValue: Bool) {
        self.label = label
        self.labelView = nil
        _isOn = State(initialValue: initialValue)
    }

    init(labelView: AnyView, initialValue: Bool) {
        self.label = nil
        self.labelView = labelView
        _isOn = State(initialValue: initialValue)
    }

    var body: some View {
        if let labelView = labelView {
            Toggle(isOn: $isOn) {
                labelView
            }
        } else {
            Toggle(label ?? "Toggle", isOn: $isOn)
        }
    }
}

struct InteractiveTextField: View {
    let placeholder: String
    @State private var text: String

    init(placeholder: String, initialValue: String) {
        self.placeholder = placeholder
        _text = State(initialValue: initialValue)
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}

struct InteractiveStepper: View {
    let label: String?
    let labelView: AnyView?
    let range: ClosedRange<Int>
    @State private var value: Int

    init(label: String, initialValue: Int, range: ClosedRange<Int>) {
        self.label = label
        self.labelView = nil
        self.range = range
        _value = State(initialValue: initialValue)
    }

    init(labelView: AnyView, initialValue: Int, range: ClosedRange<Int>) {
        self.label = nil
        self.labelView = labelView
        self.range = range
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        if let labelView = labelView {
            Stepper(value: $value, in: range) {
                labelView
            }
        } else {
            Stepper(label ?? "Stepper", value: $value, in: range)
        }
    }
}
#endif
