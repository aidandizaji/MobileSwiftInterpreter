//
//  PreviewPane.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI
import UIKit

struct PreviewPane: View {
    let view: AnyView?
    let diagnostics: [Diagnostic]
    let status: RunStatus
    let runID: Int

    var body: some View {
        ZStack {
            if let view = view, diagnostics.isEmpty {
                RenderedView(view: view)
                    .id(runID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            } else {
                placeholder
            }

            if status == .running || status == .compiling {
                progressOverlay
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .semibold))
            Text("No Preview")
                .font(.headline)
            if let message = diagnostics.first?.message {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            } else {
                Text("Run code to render a view.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private var progressOverlay: some View {
        Color.black.opacity(0.1)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            )
    }
}
