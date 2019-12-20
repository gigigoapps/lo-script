#!/usr/bin/swift

/*
    Run command in terminal with:
    > swift lo-script.swift
 
    You need to create a sharing link of the google sheet so only people with that link can download the sheet. You must append to the url "/export?format=tsv" or "export?format=tsv&sheet=0" if the sheet has more pages
     Example:  https://docs.google.com/spreadsheets/d/1GbcR_lfekamj2DKWNIXSABVm-V3wLvx6Z9Wy4B1Qrd0/export?format=tsv&sheet=0
*/

import Foundation

//
// MARK: STEP 1: ⬇️ Download Google Sheet
//

let googleSheetURL = CommandLine.arguments[1]

// Allows to run a command line tool

@discardableResult
func shell(_ args: String...) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

shell("curl", googleSheetURL, "-o", "excel.tsv")

//
// MARK: STEP 2: ⬇️ Converts Google Sheet to String files
//

let sheet = try! String(contentsOfFile: "./excel.tsv")
let fieldDelimiterCharacter = "\t"

var numberOfLanguages = 0
var foundStartingPoint = false

func handle(comment: String) -> String {
    return "\n// \(comment)\n\n"
}

func handleLine(key: String, value: String) -> String {
    return "\"\(key)\" = \"\(value)\";\n"
}

func getLanguagesFrom(sheet: String) -> [String] {
    var languages: [String] = []
    let lines = sheet.components(separatedBy: "\n")
    lines.forEach { line in
        let components = line.components(separatedBy: fieldDelimiterCharacter)
        if let firstComponent = components.first {
            if firstComponent == "[key]" {
                let lineComponents = line.components(separatedBy: fieldDelimiterCharacter)
                numberOfLanguages = lineComponents.count - 1
                languages = Array(components.dropFirst())
                return
            }
        }
    }
    return languages
}

// Save string to file

func save(_ content: String, path: String, filename: String) {
    let dataPath = URL(string: path)!
    if !FileManager.default.fileExists(atPath: dataPath.absoluteString) {
        do {
            try FileManager.default.createDirectory(atPath: dataPath.absoluteString, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error.localizedDescription)
        }
    }

    let filename = URL(fileURLWithPath: path + filename)

    do {
        try content.write(to: filename, atomically: false, encoding: .utf8)
    } catch let error as NSError {
        fputs("❌ \(error)", stderr)
        exit(-1)
    }
}

let lines = sheet.components(separatedBy: "\n")

let languages = getLanguagesFrom(sheet: sheet)

languages.forEach { language in
    let index = languages.firstIndex(of: language)!
    var result = """
    /*

    Automatically Generated - DO NOT modify manually - use the lo-script instead.

    */
    

    """
    lines.forEach { line in
        let firstDeviceComponent = line.components(separatedBy: fieldDelimiterCharacter).first!
        if !firstDeviceComponent.contains("_android") { // only in first row
            let components = line.components(separatedBy: fieldDelimiterCharacter)
            if let firstComponent = components.first {
                if firstComponent == "[key]" {
                    foundStartingPoint = true
                } else if foundStartingPoint {
                    if firstComponent == "[COMMENT]" {
                        result += handle(comment: components[index + 1])
                    } else if !firstComponent.contains("[") {
                        result += handleLine(key: firstComponent, value: components[index + 1])
                    }
                }
            }
        }
    }
    let cleanLanguageString = language.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
    save(result,
         path: "./\(cleanLanguageString).lproj/",
        filename: "Localizable.strings")
}

//
// MARK: STEP 3: 🔃 Generate Constants file
//

extension String {
    func toUpperCase() -> String {
        return self.split(separator: "_").map {$0.capitalized}.joined()
    }
    func firstWord() -> String {
        let words = self.split(separator: "_")
        return String(words.first ?? "")
    }
}

var content = """
// Automatically Generated - DO NOT modify manually - use lo-script instead.

import Foundation

// swiftlint:disable identifier_name
// swiftlint:disable file_length

"""

// Load

func loadLocalizablePlist() -> [String: String] {
    let file = "./\(languages.first ?? "en").lproj/Localizable.strings"
    guard let dictionary = NSDictionary(contentsOfFile: file) as? [String: String] else {
        fputs("❌ Wrong Localization URL: \(file)\n", stderr)
        exit(-1)
    }
    return dictionary
}

let dictionary = loadLocalizablePlist()

// Generate Content

var section = ""

let sortedKeys = Array(dictionary.keys).sorted()

for key in sortedKeys {
    
    let firstWord = key.firstWord()
    if firstWord != section {
        section = firstWord
        content += "\n// \(section.capitalized)\n\n"
    }
    content += "let kLocale\(key.toUpperCase()): String = { return NSLocalizedString(\"\(key)\", comment: \"\") }()\n"
}

content += """

// swiftlint:enable identifier_name
// swiftlint:enable file_length
"""

save(content, path: "./", filename: "LocalizableConstants.swift")
fputs("\n Finished 👍\n\n", stderr)

// Remove sheet file
shell("rm", "excel.tsv")
