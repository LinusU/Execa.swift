import Foundation
import PromiseKit

public enum ExecaIO {
    case ignore
    case inherit
    case pipe
}

public protocol ExecaProps {
    var cmd: String { get }
    var code: Int32 { get }
    var failed: Bool { get }
    // var killed: Bool { get }
    // var signal: String? { get }
    var stderrData: Data { get }
    var stdoutData: Data { get }
    // var timedOut: Bool { get }

    var stdout: String { get }
}

public extension ExecaProps {
    public var stderr: String {
        get { return String(data: stderrData, encoding: .utf8)!.stripEOF() }
    }

    public var stdout: String {
        get { return String(data: stdoutData, encoding: .utf8)!.stripEOF() }
    }
}

public struct ExecaResult: ExecaProps {
    public let cmd: String
    public let code: Int32
    public let stderrData: Data
    public let stdoutData: Data

    public var failed: Bool { get { return false } }
}

public struct ExecaError: ExecaProps, Error {
    public let cmd: String
    public let code: Int32
    public let stderrData: Data
    public let stdoutData: Data

    public var failed: Bool { get { return true } }
}

extension ExecaError: CustomStringConvertible {
    public var description: String {
        var result = "Command failed: \(cmd)"

        if stderr != "" { result += "\n\(stderr)" }
        if stdout != "" { result += "\n\(stdout)" }

        return result
    }
}

fileprivate extension String {
    func stripEOF() -> String {
        if hasSuffix("\r\n") { return String(dropLast(2)) }
        if hasSuffix("\n") { return String(dropLast(1)) }
        if hasSuffix("\r") { return String(dropLast(1)) }

        return self
    }
}

public func execa(_ file: String, _ arguments: [String] = [], stdio: ExecaIO) -> Promise<ExecaResult> {
    return execa(URL(fileURLWithPath: file, isDirectory: false), arguments, stdout: stdio, stderr: stdio)
}

public func execa(_ file: String, _ arguments: [String] = [], stdout: ExecaIO = .pipe, stderr: ExecaIO = .pipe) -> Promise<ExecaResult> {
    return execa(URL(fileURLWithPath: file, isDirectory: false), arguments, stdout: stdout, stderr: stderr)
}

public func execa(_ file: URL, _ arguments: [String] = [], stdio: ExecaIO) -> Promise<ExecaResult> {
    return execa(file, arguments, stdout: stdio, stderr: stdio)
}

public func execa(_ file: URL, _ arguments: [String] = [], stdout: ExecaIO = .pipe, stderr: ExecaIO = .pipe) -> Promise<ExecaResult> {
    let process = Process()

    let stdoutDescriptor: Any?
    let stdoutDataGetter: () -> Data
    switch stdout {
        case .ignore: stdoutDescriptor = nil; stdoutDataGetter = { Data(count: 0) }
        case .inherit: stdoutDescriptor = FileHandle(fileDescriptor: 1); stdoutDataGetter = { Data(count: 0) }
        case .pipe: stdoutDescriptor = Pipe(); stdoutDataGetter = { (stdoutDescriptor as! Pipe).fileHandleForReading.readDataToEndOfFile() }
    }

    let stderrDescriptor: Any?
    let stderrDataGetter: () -> Data
    switch stderr {
        case .ignore: stderrDescriptor = nil; stderrDataGetter = { Data(count: 0) }
        case .inherit: stderrDescriptor = FileHandle(fileDescriptor: 2); stderrDataGetter = { Data(count: 0) }
        case .pipe: stderrDescriptor = Pipe(); stderrDataGetter = { (stderrDescriptor as! Pipe).fileHandleForReading.readDataToEndOfFile() }
    }

    let joinedCommand = (arguments.count > 0 ? "\(file.path) \(arguments.joined(separator: " "))" : "\(file.path)")

    process.arguments = arguments
    process.standardError = stderrDescriptor
    process.standardOutput = stdoutDescriptor

    return Promise<ExecaResult> { seal in
        process.terminationHandler = { process in
            if process.terminationStatus == 0 {
                seal.fulfill(ExecaResult(
                    cmd: joinedCommand,
                    code: process.terminationStatus,
                    stderrData: stderrDataGetter(),
                    stdoutData: stdoutDataGetter()
                ))
            } else {
                seal.reject(ExecaError(
                    cmd: joinedCommand,
                    code: process.terminationStatus,
                    stderrData: stderrDataGetter(),
                    stdoutData: stdoutDataGetter()
                ))
            }
        }

        if #available(macOS 10.13, *) {
            process.executableURL = file

            do {
                try process.run()
            } catch {
                seal.reject(error)
            }
        } else {
            process.launchPath = file.path
            process.launch()
        }
    }
}
