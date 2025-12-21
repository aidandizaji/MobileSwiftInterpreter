//
//  LogBuffer.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation

final class LogBuffer: InterpreterLogger {
    private let lock = NSLock()
    private var lines: [String] = []
    private let maxLines: Int

    init(maxLines: Int = 500) {
        self.maxLines = maxLines
    }

    func log(_ message: String) {
        lock.lock()
        lines.append(message)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let snapshot = lines
        lock.unlock()
        return snapshot
    }

    func clear() {
        lock.lock()
        lines.removeAll()
        lock.unlock()
    }
}
