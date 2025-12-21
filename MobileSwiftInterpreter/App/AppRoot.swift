//
//  AppRoot.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI
import UIKit

enum RootTab: String, CaseIterable, Identifiable {
    case editor = "Editor"
    case preview = "Preview"
    case console = "Console"

    var id: String { rawValue }
}

struct AppRoot: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: RootTab = .editor
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .compact {
                    compactLayout
                } else {
                    regularLayout
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Swift Interpreter")
            .onAppear {
                if viewModel.autoRunEnabled {
                    viewModel.run()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear Editor")
                    Button("Run") {
                        viewModel.run()
                    }
                    Toggle("Auto-Run", isOn: Binding(
                        get: { viewModel.autoRunEnabled },
                        set: { viewModel.setAutoRunEnabled($0) }
                    ))
                    .labelsHidden()
                    statusIndicator
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu("Templates") {
                        ForEach(TemplateLibrary.templates) { template in
                            Button(template.name) {
                                viewModel.applyTemplate(template)
                            }
                        }
                    }
                }
                if horizontalSizeClass == .compact {
                    ToolbarItem(placement: .bottomBar) {
                        Picker("Mode", selection: $selectedTab) {
                            ForEach(RootTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .confirmationDialog(
                "Clear editor?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    viewModel.clearSource()
                }
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 16) {
            VStack(spacing: 12) {
                if !viewModel.diagnostics.isEmpty {
                    errorBanner
                }
                EditorView(viewModel: viewModel)
                DiagnosticsView(diagnostics: viewModel.diagnostics, onCopyLine: copyLine)
                    .frame(height: 180)
                ConsoleView(logs: viewModel.logs, onClear: viewModel.clearLogs)
                    .frame(height: 160)
            }
            PreviewPane(
                view: viewModel.currentView,
                diagnostics: viewModel.diagnostics,
                status: viewModel.status,
                runID: viewModel.runID
            )
        }
        .padding(12)
    }

    private var compactLayout: some View {
        VStack(spacing: 12) {
            if !viewModel.diagnostics.isEmpty {
                errorBanner
            }
            switch selectedTab {
            case .editor:
                EditorView(viewModel: viewModel)
                DiagnosticsView(diagnostics: viewModel.diagnostics, onCopyLine: copyLine)
                    .frame(maxHeight: 200)
            case .preview:
                PreviewPane(
                    view: viewModel.currentView,
                    diagnostics: viewModel.diagnostics,
                    status: viewModel.status,
                    runID: viewModel.runID
                )
            case .console:
                ConsoleView(logs: viewModel.logs, onClear: viewModel.clearLogs)
                DiagnosticsView(diagnostics: viewModel.diagnostics, onCopyLine: copyLine)
                    .frame(maxHeight: 200)
            }
        }
        .padding(12)
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(viewModel.status.rawValue)
                .font(.caption)
        }
    }

    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(viewModel.diagnostics.first?.message ?? "Error")
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(Color.red)
        .cornerRadius(10)
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle:
            return .gray
        case .compiling:
            return .orange
        case .running:
            return .blue
        case .ok:
            return .green
        case .error:
            return .red
        }
    }

    private func copyLine(_ line: Int) {
        UIPasteboard.general.string = "\(line)"
    }
}
