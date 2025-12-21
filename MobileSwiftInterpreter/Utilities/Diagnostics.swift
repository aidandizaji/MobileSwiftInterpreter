//
//  Diagnostics.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation

enum EnginePhase: String {
    case parse = "Parse"
    case compile = "Compile"
    case runtime = "Runtime"
    case bridge = "Bridge"
}

enum Severity: String {
    case error = "Error"
    case warning = "Warning"
}

struct Diagnostic: Identifiable, Hashable {
    let id: UUID
    let phase: EnginePhase
    let severity: Severity
    let message: String
    let line: Int?
    let column: Int?

    init(
        phase: EnginePhase,
        severity: Severity,
        message: String,
        line: Int? = nil,
        column: Int? = nil
    ) {
        self.id = UUID()
        self.phase = phase
        self.severity = severity
        self.message = message
        self.line = line
        self.column = column
    }
}
