#!/usr/bin/swift

/*
    Run command in terminal with:
    > swift lo-script.swift sheetURL device
 
    sheetURL: You need to create a sharing link of the google sheet so only people with that link can download the sheet. You must append to the url "/export?format=tsv" or "export?format=tsv&sheet=0" if the sheet has more pages
     Example:  https://docs.google.com/spreadsheets/d/1GbcR_lfekamj2DKWNIXSABVm-V3wLvx6Z9Wy4B1Qrd0/export?format=tsv&sheet=0
 
    device: "ios" or "android"
*/

import Foundation

enum Device: String {
    case ios, android
    
    func fileName() -> String {
        switch self {
        case .ios:
            return "Localizable.strings"
        case .android:
            return "strings.xml"
        }
    }
    
    func path(forLanguage language: String) -> String {
        switch self {
        case .ios:
            return "./output/\(language).lproj/"
        case .android:
            return "./output/values-\(language)/"
        }
    }
}

//
// MARK: STEP 1: ⬇️ Download Google Sheet
//

fputs("\n ✏️  Downloading Google Sheet... \n", stderr)

let googleSheetURL = CommandLine.arguments[1]
let device = CommandLine.arguments[2].lowercased() == Device.android.rawValue ? Device.android : Device.ios

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

fputs("\n ✏️  Converting Google Sheet to String files... \n", stderr)

let sheet = try! String(contentsOfFile: "./excel.tsv")
let rowDelimiterCharacter = "\r\n"
let columnDelimiterCharacter = "\t"

var numberOfLanguages = 0

func handle(comment: String) -> String {
    switch device {
    case .ios:
        return "\n// \(comment)\n\n"
    case .android:
        return "\n<!-- \(comment) -->\n"

    }
}

func handleLine(key: String, value: String) -> String {
    switch device {
    case .ios:
        return "\"\(key)\" = \"\(value)\";\n"
    case .android:
        return "<string name=\"\(key)\">\(value)</string>\n"
    }
}

func getLanguagesFrom(sheet: String) -> [String] {
    var languages: [String] = []
    let lines = sheet.components(separatedBy: rowDelimiterCharacter)
    lines.forEach { line in
        let components = line.components(separatedBy: columnDelimiterCharacter)
        if let firstComponent = components.first {
            if firstComponent == "[key]" {
                let lineComponents = line.components(separatedBy: columnDelimiterCharacter)
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

func templateFile(for device: Device) -> String {
    switch device {
    case .ios:
        return """
        /*

        Automatically Generated - DO NOT modify manually - use lo-script instead.
        
        */
        
        {{lo-script-content}}
        """
    case .android:
        return """
        /*
        
        Automatically Generated - DO NOT modify manually - use lo-script instead.
        
        */
        
        <resources>
        {{lo-script-content}}
        </resources>
        """
    }
}

let lines = sheet.components(separatedBy: rowDelimiterCharacter)

let languages = getLanguagesFrom(sheet: sheet)

languages.forEach { language in
    var foundStartingPoint = false

    let index = languages.firstIndex(of: language)!
    let keyToIgnore = device == Device.ios ? "_android" : "_ios"
    var result = ""
    
    lines.forEach { line in
        let firstDeviceComponent = line.components(separatedBy: columnDelimiterCharacter).first!
        if !firstDeviceComponent.contains(keyToIgnore) { // only in first row
            let components = line.components(separatedBy: columnDelimiterCharacter)
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
    
    result = templateFile(for: device).replacingOccurrences(of: "{{lo-script-content}}", with: result)
    
    save(result,
         path: device.path(forLanguage: language),
        filename: device.fileName())
}

// Remove sheet file
shell("rm", "excel.tsv")

if device == .android {
    fputs("\n Finished 👍\n\n", stderr)
    exit(0)
}

//
// MARK: STEP 3: 🔃 Generate Constants file
//

fputs("\n ✏️  Generating Constants file... \n", stderr)

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
    let language = languages.first ?? "en"
    let file = device.path(forLanguage: language) + device.fileName()
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

save(content, path: "./output/", filename: "LocalizableConstants.swift")
fputs("\n Finished 👍\n\n", stderr)




