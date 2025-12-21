# MobileSwiftInterpreter

[![Platform](https://img.shields.io/badge/platform-iOS-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/swift-5.9-orange)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/xcode-16.2-blue)](https://developer.apple.com/xcode/)

MobileSwiftInterpreter is a SwiftUI playground-style app that compiles and runs a safe, sandboxed subset of Swift and SwiftUI directly on-device. Write SwiftUI code in the editor, tap Run, and see a live preview update instantly.

---

## Table of Contents
- Overview
- Highlights
- Quick Start
- Multi-File Input
- Example
- Supported Surface
- Architecture
- Folder Guide
- Limitations
- Roadmap
- Contributing

---

## Overview
This app ships a small bytecode VM and a SwiftSyntax-based compiler. The goal is fast iteration and safe execution of SwiftUI code without shipping a full compiler toolchain.

---

## Highlights
| Feature | Details |
| --- | --- |
| Live SwiftUI preview | Render SwiftUI in real time inside the app |
| State + bindings | `@State` and `$binding` for interactive controls |
| Safe API surface | Explicit allowlist for types, modifiers, and functions |
| Multi-file support | Split code with inline file markers |
| SwiftSyntax powered | Parse Swift directly in-app |

---

## Quick Start
1. Open `MobileSwiftInterpreter.xcodeproj` in Xcode.
2. Build and run on iOS Simulator or a device.
3. Edit code in the app and tap Run.

---

## Multi-File Input
Split sources inside the editor using file markers:

```swift
// File: Models.swift
struct TipOption {
    let percent: Int
}

// File: AppView.swift
import SwiftUI

struct AppView: View {
    var body: some View {
        Text("Hello")
    }
}
```

---

## Example
This snippet demonstrates bindings, computed properties, and UI styling:

```swift
import SwiftUI

struct AppView: View {
    @State private var bill = ""
    @State private var tipPercent = 15

    private var amount: Double {
        Double(bill) ?? 0
    }

    private var total: Double {
        amount + (amount * Double(tipPercent) / 100)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Tip Calculator")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("0.00", text: $bill)
                .keyboardType(.decimalPad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            HStack(spacing: 12) {
                ForEach([10, 15, 20], id: \.self) { percent in
                    Button {
                        tipPercent = percent
                    } label: {
                        Text("\(percent)%")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                tipPercent == percent ? Color.blue : Color(.systemGray6)
                            )
                            .foregroundColor(
                                tipPercent == percent ? .white : .primary
                            )
                            .cornerRadius(10)
                    }
                }
            }

            HStack {
                Text("Total")
                Spacer()
                Text("$\(total, specifier: \"%.2f\")")
                    .fontWeight(.bold)
            }
        }
        .padding()
    }
}
```

---

## Supported Surface (Partial)
- **Controls:** `Button`, `TextField`, `Toggle`, `Slider`, `Stepper`
- **Layout:** `VStack`, `HStack`, `List`, `NavigationStack`, `NavigationLink`, `Spacer`
- **Views:** `Text`, `Divider`, `Rectangle`, `Circle`
- **Modifiers:** `padding`, `background`, `foregroundColor`, `cornerRadius`, `font`, `fontWeight`, `frame`, `navigationTitle`, `onTapGesture`
- **Types:** `Double`, `ClosedRange`, `Color`
- **State:** `@State`, `$binding` for supported controls

---

## Architecture
```
Swift Source
    |
    v
SwiftSyntax Parser
    |
    v
Compiler -> Bytecode -> Interpreter -> SwiftUI
```

---

## Folder Guide
- `MobileSwiftInterpreter/App` - App root, view model, bootstrapping
- `MobileSwiftInterpreter/Views` - Editor, preview, console, diagnostics, interpreted view
- `MobileSwiftInterpreter/Engine` - Parser, compiler, bytecode, run controller
- `MobileSwiftInterpreter/Interpreter` - Runtime VM and SwiftUI bridges
- `MobileSwiftInterpreter/Utilities` - State store, logging, diagnostics, helpers
- `MobileSwiftInterpreter/Stubs` - SwiftUI stubs and fallback controls

---

## Limitations
This project intentionally runs a safe subset of Swift and SwiftUI. Not all APIs or language features are supported. To extend functionality, update the whitelist and runtime bridge in the interpreter.

---

## Roadmap
- Expand SwiftUI modifier coverage (layout, animation, styling)
- Add richer data-driven lists and ForEach support
- Improve interpolation formatting (`specifier`)
- Add tests for compiler and runtime

---

## Contributing
Pull requests and feature requests are welcome. If you add new SwiftUI APIs, please update the whitelist and include a short example in this README.
