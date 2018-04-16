# Execa

Executing of subprocesses made easy.

This is a Swift port of the JavaScript library [execa](https://github.com/sindresorhus/execa).

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/LinusU/Execa.swift", from: "1.0.0"),
]
```

## Usage

```swift
import Execa

execa("/bin/echo", ["unicorns"]).done {
  print($0.stdout)
  //=> unicorns
}

execa("/bin/sh", ["-c", "exit 3"]).catch {
  guard let err = $0 as? ExecaError else { throw $0 }

  print("\(err)")
  //=> Command failed: /bin/sh -c exit 3

  print("\(err.code)")
  //=> 3
}
```
