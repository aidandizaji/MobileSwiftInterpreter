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
        TextEditor(text: $viewModel.source)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .onChange(of: viewModel.source) { _ in
                viewModel.handleSourceChange()
            }
    }
}
