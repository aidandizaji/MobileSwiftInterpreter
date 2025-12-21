//
//  ConsoleView.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import SwiftUI
import UIKit

struct ConsoleView: View {
    let logs: [String]
    let onClear: () -> Void

    var body: some View {
        GroupBox {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.footnote, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                    }
                }
                .onChange(of: logs.count) { _ in
                    if let last = logs.indices.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Label("Console", systemImage: "terminal")
                    .font(.subheadline)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.subheadline)
            }
        }
    }
}
