// main.swift
// mousecloak
//
// Swift-native CLI entry point — replaces GBCli with inline argument parsing.

import Foundation
import AppKit

// MARK: - ANSI colours

private let bold  = "\u{001B}[1m"
private let reset = "\u{001B}[0m"
private let white = "\u{001B}[37m"
private let red   = "\u{001B}[31m"
private let green = "\u{001B}[32m"

// MARK: - Argument parser

/// Minimal argument parser — processes flags with optional/required values.
private struct ArgParser {
    private var raw: [String]

    init(_ args: [String]) { self.raw = args }

    /// Whether a flag (long or short) is present.
    func has(_ long: String, short: Character? = nil) -> Bool {
        return raw.contains("--\(long)")
            || raw.contains("-\(short.map(String.init) ?? "__none__")")
    }

    /// Value for the flag that immediately follows the flag token.
    func value(for long: String, short: Character? = nil) -> String? {
        let flags = ["--\(long)"]
            + (short.map { ["-\(String($0))"] } ?? [])
        for flag in flags {
            if let idx = raw.firstIndex(of: flag), raw.index(after: idx) < raw.endIndex {
                let next = raw[raw.index(after: idx)]
                if !next.hasPrefix("-") { return next }
            }
        }
        return nil
    }
}

// MARK: - Help text

private func printHelp() {
    print("""
\(bold)\(white)mousecloak v2.0\(reset)

\(bold)APPLYING CAPES\(reset)
  -a, --apply <path>      Apply a cape
  -r, --reset             Reset to the default macOS cursors

\(bold)CREATING CAPES\(reset)
  -c, --create <path>     Create a cursor from a folder (default output: same directory)
  -d, --dump   <path>     Dump the currently applied cursors to a file
  -x, --convert <path>    Convert a .MightyMouse file to cape

\(bold)MISCELLANEOUS\(reset)
  -e, --export <path>     Export a cape to a directory
  -o, --output <path>     Output file/directory path
  -s, --scale  [value]    Get or set the cursor scale
      --listen            Re-apply the current cape on every user-session change
  -?, --help              Display this help and exit

\(bold)\(white)Copyright © 2013-2024 Alex Zielenski\(reset)
""")
}

// MARK: - main

let args = Array(CommandLine.arguments.dropFirst())  // drop program name
let parser = ArgParser(args)

let suppressCopyright = parser.has("suppressCopyright")

if parser.has("help", short: "?") || args.isEmpty {
    printHelp()
    exit(EXIT_SUCCESS)
}

if !suppressCopyright {
    print("\(bold)\(white)mousecloak v2.0\(reset)")
}

let doReset   = parser.has("reset",   short: "r")
let doApply   = parser.has("apply",   short: "a")
let doCreate  = parser.has("create",  short: "c")
let doDump    = parser.has("dump",    short: "d")
let doConvert = parser.has("convert", short: "x")
let doExport  = parser.has("export",  short: "e")
let doScale   = parser.has("scale",   short: "s")
let doListen  = parser.has("listen")

let cmdCount = [doReset, doApply, doCreate, doDump, doConvert, doExport, doScale, doListen]
    .filter { $0 }.count

if cmdCount > 1 {
    MMLog("\(bold)\(red)One command at a time, son!\(reset)")
    if !suppressCopyright { print("\(bold)\(white)Copyright © 2013-2024 Alex Zielenski\(reset)") }
    exit(0)
}

func fin() {
    if !suppressCopyright { print("\(bold)\(white)Copyright © 2013-2024 Alex Zielenski\(reset)") }
}

if doReset {
    resetAllCursors()
    fin(); exit(EXIT_SUCCESS)
}

if doApply {
    guard let path = parser.value(for: "apply", short: "a") else {
        MMLog("\(bold)\(red)--apply requires a path argument\(reset)")
        fin(); exit(EXIT_FAILURE)
    }
    applyCapeAtPath(path)
    fin(); exit(EXIT_SUCCESS)
}

if doCreate || doConvert {
    let key = doCreate ? "create" : "convert"
    let ch: Character = doCreate ? "c" : "x"
    guard let input = parser.value(for: key, short: ch) else {
        MMLog("\(bold)\(red)--\(key) requires a path argument\(reset)")
        fin(); exit(EXIT_FAILURE)
    }
    let output = parser.value(for: "output", short: "o")
        ?? (input as NSString).deletingLastPathComponent

    if let error = createCape(input, output: output, convert: doConvert) {
        MMLog("\(bold)\(red)\(error.localizedDescription)\(reset)")
    } else {
        MMLog("\(bold)\(green)Cape successfully written to \(output)\(reset)")
    }
    fin(); exit(EXIT_SUCCESS)
}

if doExport {
    guard let input = parser.value(for: "export", short: "e") else {
        MMLog("\(bold)\(red)--export requires a path argument\(reset)")
        fin(); exit(EXIT_FAILURE)
    }
    guard let output = parser.value(for: "output", short: "o") else {
        MMLog("\(bold)\(red)You must specify an output directory with -o!\(reset)")
        fin(); exit(EXIT_FAILURE)
    }
    if let cape = NSDictionary(contentsOfFile: input) as? [String: Any] {
        exportCape(cape, destination: output)
    }
    fin(); exit(EXIT_SUCCESS)
}

if doDump {
    guard let dumpPath = parser.value(for: "dump", short: "d") else {
        MMLog("\(bold)\(red)--dump requires a path argument\(reset)")
        fin(); exit(EXIT_FAILURE)
    }
    dumpCursorsToFile(dumpPath) { progress, total in
        MMLog("Dumped \(progress) of \(total)")
        return true
    }
    fin(); exit(EXIT_SUCCESS)
}

if doScale {
    if let valueStr = parser.value(for: "scale", short: "s"),
       let value = Float(valueStr) {
        setCursorScale(value)
    } else {
        MMLog("\(cursorScale())")
    }
    fin(); exit(EXIT_SUCCESS)
}

if doListen {
    listener()
    fin(); exit(EXIT_SUCCESS)
}

fin()
exit(EXIT_SUCCESS)
