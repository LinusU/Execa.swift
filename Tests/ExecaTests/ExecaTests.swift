import XCTest
import PromiseKit
import Execa

extension XCTestCase {
    func waitedExpectation(description: String, _ promiseFactory: () -> Promise<Void>) {
        expectation(description: description, promiseFactory)
        waitForExpectations(timeout: 10)
    }

    func expectation(description: String, _ promiseFactory: () -> Promise<Void>) {
        let done = self.expectation(description: "Promise \(description) settled")

        firstly {
            promiseFactory()
        }.catch { err in
            XCTFail("Failed with error: \(err)")
        }.finally {
            done.fulfill()
        }
    }
}

enum ExpectRejectionError: Error {
    case missingExpectedRejection
    case unexpectedRejection(Error)
}

func expectRejection<T, E: Error>(_ type: E.Type, _ promise: Promise<T>) -> Promise<E> {
    return Promise<E> { seal in
        promise.done { _ in
            seal.reject(ExpectRejectionError.missingExpectedRejection)
        }.catch { err in
            guard let result = err as? E else {
                return seal.reject(ExpectRejectionError.unexpectedRejection(err))
            }

            seal.fulfill(result)
        }
    }
}

let fixturesPath = NSString(string: "\(#file)/../../../Fixtures").standardizingPath

final class ExecaTests: XCTestCase {
    func testEchoHello() {
        waitedExpectation(description: "echo Hello") {
            firstly {
                execa("/bin/echo", ["Hello,", "World!"])
            }.done {
                XCTAssertEqual($0.failed, false)
                XCTAssertEqual($0.stdout, "Hello, World!")
            }
        }
    }

    func testExeca() {
        waitedExpectation(description: "execa") {
            firstly {
                execa("\(fixturesPath)/noop", ["foo"])
            }.done {
                XCTAssertEqual($0.failed, false)
                XCTAssertEqual($0.stdout, "foo")
            }
        }
    }

    func testData() {
        waitedExpectation(description: "data") {
            firstly {
                execa("\(fixturesPath)/noop", ["foo"])
            }.done {
                XCTAssertEqual($0.failed, false)
                XCTAssertEqual($0.stdoutData, "foo\n".data(using: .utf8))
            }
        }
    }

    func testStdoutStderrAvailableOnErrors() {
        waitedExpectation(description: "stdoutStderrAvailableOnErrors") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/exit", ["2"]))
            }.done {
                XCTAssertEqual($0.code, 2)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdoutData, Data(count: 0))
                XCTAssertEqual($0.stderrData, Data(count: 0))
            }
        }
    }

    func testIncludeStdoutAndStderrInErrorsForImprovedDebugging() {
        waitedExpectation(description: "includeStdoutAndStderrInErrorsForImprovedDebugging") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/error-message"))
            }.done {
                XCTAssertEqual($0.code, 1)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdout, "stdout")
                XCTAssertEqual($0.stderr, "stderr")
                XCTAssertEqual(String(describing: $0), "Command failed: \(fixturesPath)/error-message\nstderr\nstdout")
            }
        }
    }

    func testDoNotIncludeInErrorsWhenStdioIsSetToInherit() {
        waitedExpectation(description: "doNotIncludeInErrorsWhenStdioIsSetToInherit") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/error-message", stdio: .inherit))
            }.done {
                XCTAssertEqual($0.code, 1)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdout, "")
                XCTAssertEqual($0.stderr, "")
                XCTAssertEqual(String(describing: $0), "Command failed: \(fixturesPath)/error-message")
            }
        }
    }

    func testDoNotIncludeStderrAndStdoutInErrorsWhenSetToInherit() {
        waitedExpectation(description: "doNotIncludeStderrAndStdoutInErrorsWhenSetToInherit") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/error-message", stdout: .inherit, stderr: .inherit))
            }.done {
                XCTAssertEqual($0.code, 1)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdout, "")
                XCTAssertEqual($0.stderr, "")
                XCTAssertEqual(String(describing: $0), "Command failed: \(fixturesPath)/error-message")
            }
        }
    }

    func testDoNotIncludeStdoutInErrorsWhenSetToInherit() {
        waitedExpectation(description: "doNotIncludeStdoutInErrorsWhenSetToInherit") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/error-message", stdout: .inherit))
            }.done {
                XCTAssertEqual($0.code, 1)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdout, "")
                XCTAssertEqual($0.stderr, "stderr")
                XCTAssertEqual(String(describing: $0), "Command failed: \(fixturesPath)/error-message\nstderr")
            }
        }
    }

    func testDoNotIncludeStderrInErrorsWhenSetToInherit() {
        waitedExpectation(description: "doNotIncludeStderrInErrorsWhenSetToInherit") {
            firstly {
                expectRejection(ExecaError.self, execa("\(fixturesPath)/error-message", stderr: .inherit))
            }.done {
                XCTAssertEqual($0.code, 1)
                XCTAssertEqual($0.failed, true)
                XCTAssertEqual($0.stdout, "stdout")
                XCTAssertEqual($0.stderr, "")
                XCTAssertEqual(String(describing: $0), "Command failed: \(fixturesPath)/error-message\nstdout")
            }
        }
    }

    static var allTests = [
        ("testEchoHello", testEchoHello),
        ("testExeca", testExeca),
        ("testData", testData),
        ("testStdoutStderrAvailableOnErrors", testStdoutStderrAvailableOnErrors),
        ("testIncludeStdoutAndStderrInErrorsForImprovedDebugging", testIncludeStdoutAndStderrInErrorsForImprovedDebugging),
        ("testDoNotIncludeInErrorsWhenStdioIsSetToInherit", testDoNotIncludeInErrorsWhenStdioIsSetToInherit),
        ("testDoNotIncludeStdoutInErrorsWhenSetToInherit", testDoNotIncludeStdoutInErrorsWhenSetToInherit),
        ("testDoNotIncludeStderrInErrorsWhenSetToInherit", testDoNotIncludeStderrInErrorsWhenSetToInherit),
    ]
}
