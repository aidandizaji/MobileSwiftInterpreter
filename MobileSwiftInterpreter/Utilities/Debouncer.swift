//
//  Debouncer.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

import Foundation

final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func schedule(action: @escaping @Sendable () -> Void) {
        task?.cancel()
        task = Task {
            let delayNanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
