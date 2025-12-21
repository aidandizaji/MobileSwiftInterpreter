//
//  DiagnosticsView.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI
import UIKit

struct DiagnosticsView: View {
    let diagnostics: [Diagnostic]
    let onCopyLine: (Int) -> Void

    var body: some View {
        GroupBox {
            if diagnostics.isEmpty {
                Text("No issues detected.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(diagnostics) { diagnostic in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(diagnostic.severity.rawValue.uppercased())
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(diagnostic.severity == .error ? Color.red.opacity(0.2) : Color.yellow.opacity(0.2))
                                        .cornerRadius(4)
                                    Text(diagnostic.phase.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if let line = diagnostic.line {
                                        Button("Copy L\(line)") {
                                            onCopyLine(line)
                                        }
                                        .font(.caption)
                                    }
                                }
                                Text(diagnostic.message)
                                    .font(.subheadline)
                                if let line = diagnostic.line, let column = diagnostic.column {
                                    Text("Line \(line), Column \(column)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        } label: {
            Label("Diagnostics", systemImage: "exclamationmark.triangle")
                .font(.subheadline)
        }
    }
}
