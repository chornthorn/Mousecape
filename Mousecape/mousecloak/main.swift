// main.swift
// mousecloak
//
// Swift replacement for main.m (mousecloak CLI tool)

import Foundation
import AppKit

// MARK: - GBOptionsHelper helper extension

extension GBOptionsHelper {
    /// Expand %APPNAME / %APPVERSION / %APPBUILD placeholders and print the result.
    func printStringFromBlock(_ block: GBOptionStringBlock!) {
        guard let block = block, let str = block() else { return }
        var result = str
        result = result.replacingOccurrences(of: "%APPNAME",    with: applicationName?() ?? "")
        result = result.replacingOccurrences(of: "%APPVERSION", with: applicationVersion?() ?? "")
        result = result.replacingOccurrences(of: "%APPBUILD",   with: applicationBuild?() ?? "")
        print(result)
    }
}

// MARK: - main

let settings = GBSettings(name: "mousecape", parent: nil)!
let options  = GBOptionsHelper()

let bold  = "\u{001B}[1m"
let reset = "\u{001B}[0m"
let white = "\u{001B}[37m"
let red   = "\u{001B}[31m"
let green = "\u{001B}[32m"

options.registerSeparator("\(bold)APPLYING CAPES\(reset)")
// Convenience type aliases for GBCli flags
let kFlagRequired  = UInt(GBValueRequired)
let kFlagOptional  = UInt(GBValueOptional)
let kFlagNone      = UInt(GBValueNone)
let kFlagNoHelpPrint = UInt(GBValueNone) | UInt(GBOptionNoHelp) | UInt(GBOptionNoPrint)

options.registerOption(Int8(Character("a").asciiValue!), long: "apply",
                       description: "Apply a cape", flags: kFlagRequired)
options.registerOption(Int8(Character("r").asciiValue!), long: "reset",
                       description: "Reset to the default OSX cursors", flags: kFlagNone)
options.registerSeparator("\(bold)CREATING CAPES\(reset)")
options.registerOption(Int8(Character("c").asciiValue!), long: "create",
                       description:
    "Create a cursor from a folder. Default output is to a new file of the same name.",
                       flags: kFlagRequired)
options.registerOption(Int8(Character("d").asciiValue!), long: "dump",
                       description: "Dumps the currently applied cursors to a file.",
                       flags: kFlagRequired)
options.registerSeparator("\(bold)CONVERTING MIGHTYMOUSE TO CAPE\(reset)")
options.registerOption(Int8(Character("x").asciiValue!), long: "convert",
                       description: "Convert a .MightyMouse file to cape.", flags: kFlagRequired)
options.registerSeparator("\(bold)MISCELLANEOUS\(reset)")
options.registerOption(Int8(Character("e").asciiValue!), long: "export",
                       description: "Export a cape to a directory", flags: kFlagRequired)
options.registerOption(Int8(Character("?").asciiValue!), long: "help",
                       description: "Display this help and exit", flags: kFlagNone)
options.registerOption(Int8(Character("o").asciiValue!), long: "output",
                       description: "Use this option to tell where an output file goes.",
                       flags: kFlagRequired)
options.registerOption(0, long: "suppressCopyright",
                       description: "Suppress Copyright info",
                       flags: kFlagNoHelpPrint)
options.registerOption(Int8(Character("s").asciiValue!), long: "scale",
                       description: "Scale the cursor or get the current scale",
                       flags: kFlagOptional)
options.registerOption(0, long: "listen",
                       description: "Keep mousecloak alive to apply the current Cape every user switch",
                       flags: kFlagNoHelpPrint)

options.applicationName    = { "mousecloak" }
options.applicationVersion = { "2.0" }
options.applicationBuild   = { "" }
options.printHelpHeader    = { "\(bold)\(white)%APPNAME v%APPVERSION\(reset)" }
options.printHelpFooter    = { "\(bold)\(white)Copyright © 2013-20 Alex Zielenski\(reset)" }

let parser = GBCommandLineParser()
options.registerOptions(toCommandLineParser: parser)

var argc_count = CommandLine.argc
var argv_ptr   = CommandLine.unsafeArgv

parser.parseOptions(withArguments: argv_ptr, count: Int32(argc_count)) { flags, option, value, stop in
    switch flags {
    case GBParseFlagUnknownOption:
        MMLog("\(bold)\(red)Unknown command line option \(option ?? ""), try --help!\(reset)")
    case GBParseFlagMissingValue:
        MMLog("\(bold)\(red)Missing value for command line option \(option ?? ""), try --help!\(reset)")
    case GBParseFlagArgument:
        if let v = value as? String { settings.setObject(true, forKey: v) }
    case GBParseFlagOption:
        if let k = option { settings.setObject(value, forKey: k) }
    default: break
    }
}

if settings.bool(forKey: "help") || argc_count == 1 {
    options.printHelp()
    exit(EXIT_SUCCESS)
}

let suppressCopyright = settings.bool(forKey: "suppressCopyright")
if !suppressCopyright { options.printStringFromBlock(options.printHelpHeader) }

if settings.bool(forKey: "reset") {
    resetAllCursors()
    if !suppressCopyright { options.printStringFromBlock(options.printHelpFooter) }
    exit(EXIT_SUCCESS)
}

let doConvert = settings.isKeyPresent(atThisLevel: "convert")
let doApply   = settings.isKeyPresent(atThisLevel: "apply")
let doCreate  = settings.isKeyPresent(atThisLevel: "create")
let doDump    = settings.isKeyPresent(atThisLevel: "dump")
let doScale   = settings.isKeyPresent(atThisLevel: "scale")
let doListen  = settings.isKeyPresent(atThisLevel: "listen")
let doExport  = settings.isKeyPresent(atThisLevel: "export")

let cmdCount = [doConvert, doApply, doCreate, doDump, doScale, doListen, doExport]
    .filter { $0 }.count

if cmdCount > 1 {
    MMLog("\(bold)\(red)One command at a time, son!\(reset)")
    if !suppressCopyright { options.printStringFromBlock(options.printHelpFooter) }
    exit(0)
}

func fin() {
    if !suppressCopyright { options.printStringFromBlock(options.printHelpFooter) }
}

if doApply {
    applyCapeAtPath(settings.object(forKey: "apply") as! String)
    fin(); exit(EXIT_SUCCESS)
}

if doCreate || doConvert {
    let input  = doCreate
        ? (settings.object(forKey: "create") as! String)
        : (settings.object(forKey: "convert") as! String)
    let output = settings.isKeyPresent(atThisLevel: "output")
        ? (settings.object(forKey: "output") as! String)
        : (input as NSString).deletingLastPathComponent

    if let error = createCape(input, output: output, convert: doConvert) {
        MMLog("\(bold)\(red)\(error.localizedDescription)\(reset)")
    } else {
        MMLog("\(bold)\(green)Cape successfully written to \(output)\(reset)")
    }
    fin(); exit(EXIT_SUCCESS)
}

if doExport {
    let input  = settings.object(forKey: "export") as! String
    guard settings.isKeyPresent(atThisLevel: "output") else {
        MMLog("\(bold)\(red)You must specify an output directory with -o!\(reset)")
        fin(); exit(EXIT_SUCCESS)
    }
    let output = settings.object(forKey: "output") as! String
    if let cape = NSDictionary(contentsOfFile: input) as? [String: Any] {
        exportCape(cape, destination: output)
    }
    fin(); exit(EXIT_SUCCESS)
}

if doDump {
    let dumpPath = settings.object(forKey: "dump") as! String
    dumpCursorsToFile(dumpPath) { progress, total in
        MMLog("Dumped \(progress) of \(total)")
        return true
    }
    fin(); exit(EXIT_SUCCESS)
}

if doScale {
    if argc_count == 2 {
        MMLog("\(cursorScale())")
    } else {
        let number = settings.object(forKey: "scale") as? NSNumber
        setCursorScale(number?.floatValue ?? 1.0)
    }
    fin(); exit(EXIT_SUCCESS)
}

if doListen {
    listener()
    fin(); exit(EXIT_SUCCESS)
}

fin()
exit(EXIT_SUCCESS)
