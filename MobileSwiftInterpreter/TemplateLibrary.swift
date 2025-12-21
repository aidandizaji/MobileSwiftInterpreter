//
//  TemplateLibrary.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation

struct Template: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let code: String
}

enum TemplateLibrary {
    static let templates: [Template] = [
        Template(
            name: "Hello Text",
            description: "Render a single Text view.",
            code: """
            import SwiftUI

            struct AppView: View {
                var body: some View {
                    Text("Hello, Interpreter")
                }
            }
            """
        ),
        Template(
            name: "Conditional",
            description: "Use a conditional expression.",
            code: """
            import SwiftUI

            struct AppView: View {
                var body: some View {
                    if "hello".uppercased() == "HELLO" {
                        Text("Works")
                    } else {
                        Text("Broken")
                    }
                }
            }
            """
        ),
        Template(
            name: "VStack List",
            description: "Stack multiple Text views.",
            code: """
            import SwiftUI

            struct AppView: View {
                var body: some View {
                    VStack {
                        Text("One")
                        Text("Two")
                        Text("Three")
                    }
                }
            }
            """
        ),
        Template(
            name: "Shape",
            description: "Render a simple shape.",
            code: """
            import SwiftUI

            struct AppView: View {
                var body: some View {
                    Rectangle().padding()
                }
            }
            """
        )
    ]
}
