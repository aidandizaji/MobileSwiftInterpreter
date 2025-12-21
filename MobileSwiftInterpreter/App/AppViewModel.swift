//
//  AppViewModel.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation
import SwiftUI

enum RunStatus: String {
    case idle = "Idle"
    case compiling = "Compiling"
    case running = "Running"
    case ok = "OK"
    case error = "Error"
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var source: String
    @Published var currentView: AnyView?
    @Published var diagnostics: [Diagnostic]
    @Published var logs: [String]
    @Published var status: RunStatus
    @Published var autoRunEnabled: Bool

    private let runController: RunController
    private let logBuffer: LogBuffer
    private let debouncer: Debouncer
    private let stateStore: StateStore
    private let lastSourceKey = "lastSource"
    private let autoRunKey = "autoRunEnabled"

    @Published private(set) var runID: Int = 0
    var currentTask: Task<Void, Never>?

    init(
        runController: RunController = RunController(),
        logBuffer: LogBuffer = LogBuffer(),
        debouncer: Debouncer = Debouncer(delay: 0.4),
        stateStore: StateStore = StateStore()
    ) {
        self.runController = runController
        self.logBuffer = logBuffer
        self.debouncer = debouncer
        self.stateStore = stateStore
        let savedSource = UserDefaults.standard.string(forKey: lastSourceKey)
        self.source = savedSource ?? TemplateLibrary.templates.first?.code ?? ""
        self.autoRunEnabled = UserDefaults.standard.bool(forKey: autoRunKey)
        self.currentView = nil
        self.diagnostics = []
        self.logs = []
        self.status = .idle
    }

    func handleSourceChange() {
        UserDefaults.standard.set(source, forKey: lastSourceKey)
        stateStore.reset()
        if autoRunEnabled {
            debouncer.schedule { [weak self] in
                Task { @MainActor in
                    self?.run()
                }
            }
        }
    }

    func setAutoRunEnabled(_ enabled: Bool) {
        autoRunEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: autoRunKey)
        if enabled {
            handleSourceChange()
        }
    }

    func applyTemplate(_ template: Template) {
        source = template.code
        stateStore.reset()
        handleSourceChange()
    }

    func clearLogs() {
        logBuffer.clear()
        logs = []
    }

    func clearSource() {
        source = ""
        UserDefaults.standard.set(source, forKey: lastSourceKey)
        stateStore.reset()
        handleSourceChange()
    }

    func run() {
        currentTask?.cancel()
        let snapshot = source
        status = .compiling
        diagnostics = []
        logBuffer.clear()
        currentTask = Task { [runController, logBuffer, stateStore] in
            await MainActor.run {
                self.status = .running
            }
            let result = await runController.run(source: snapshot, logBuffer: logBuffer, stateStore: stateStore)
            let logSnapshot = logBuffer.snapshot()
            await MainActor.run {
                self.logs = logSnapshot
                switch result {
                case .success(_, let program):
                    self.runID += 1
                    let rendered = InterpretedView(
                        program: program,
                        engine: runController.engine,
                        stateStore: stateStore,
                        logBuffer: logBuffer
                    )
                    self.currentView = AnyView(rendered)
                    self.status = .ok
                case .failure(let diagnostics):
                    self.diagnostics = diagnostics
                    self.status = .error
                case .cancelled:
                    self.status = .idle
                }
            }
        }
    }
}
