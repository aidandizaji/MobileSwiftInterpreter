//
//  EditorView.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI
import UIKit

struct EditorView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox {
            TextEditor(text: $viewModel.source)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator).opacity(0.25), lineWidth: 1)
                )
                .onChange(of: viewModel.source) { _ in
                    viewModel.handleSourceChange()
                }
        } label: {
            Label("Editor", systemImage: "chevron.left.slash.chevron.right")
                .font(.subheadline)
        }
    }
}
