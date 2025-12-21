//
//  Bytecode.swift
//  MobileSwiftInterpreter
//
//  Created by Aidan Dizaji on 2025-12-19.
//

struct Bytecode {
    static let intByteWidth = 8
    static let boolByteWidth = 1

    var bytes: [UInt8]

    init(bytes: [UInt8] = []) {
        self.bytes = bytes
    }

    var count: Int {
        bytes.count
    }

    mutating func appendOp(_ op: Operation) {
        bytes.append(op.rawValue)
    }

    mutating func appendInt(_ value: Int) {
        var raw = Int64(value).littleEndian
        withUnsafeBytes(of: &raw) { buffer in
            bytes.append(contentsOf: buffer)
        }
    }

    mutating func appendBool(_ value: Bool) {
        bytes.append(value ? 1 : 0)
    }

    mutating func appendSymbol(_ id: Int) {
        appendInt(id)
    }

    mutating func writeInt(_ value: Int, at index: Int) {
        var raw = Int64(value).littleEndian
        let data = withUnsafeBytes(of: &raw) { Array($0) }
        for offset in 0..<Bytecode.intByteWidth {
            bytes[index + offset] = data[offset]
        }
    }
}
