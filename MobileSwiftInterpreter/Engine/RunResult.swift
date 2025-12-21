//
//  RunResult.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI

enum RunResult {
    case success(view: AnyView)
    case failure(diagnostics: [Diagnostic])
    case cancelled
}
