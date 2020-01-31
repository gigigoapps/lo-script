//
//  FileManager.swift
//  Lo-Script
//
//  Created by Sergio.Lopez on 1/2/20.
//  Copyright © 2020 Sergio.Lopez. All rights reserved.
//

import Foundation

enum Device: String { case ios, android }

struct FileHelper {
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
}
//
//  StringFile.swift
//  Lo-Script
//
//  Created by Sergio.Lopez on 1/2/20.
//  Copyright © 2020 Sergio.Lopez. All rights reserved.
//

import Foundation

struct StringFile {

    let content: String
    let device: Device
    let language: String

    init(rows: [Sheet.Row], device: Device, language: String) {
        self.device = device
        self.language = language
        self.content = StringFileParser(device: device).parse(rows: rows)
    }

    func save() {
        FileHelper().save(self.content,
                          path: self.path(),
                          filename: self.fileName())
    }

    private func fileName() -> String {
        switch self.device {
        case .ios:
            return "Localizable.strings"
        case .android:
            return "strings.xml"
        }
    }

    private func path() -> String {
        switch self.device {
        case .ios:
            return "./output/\(self.language).lproj/"
        case .android:
            return "./output/values-\(self.language)/"
        }
    }
}

// MARK: Parser

private struct StringFileParser {

    let device: Device

    func parse(rows: [Sheet.Row]) -> String {
        let content = rows.reduce("") { (content, row) -> String in
            switch row.type {
            case .comment(let comment):
                return content + self.comment(from: comment)
            case .translation(let key, let value):
                return content + self.lineFrom(key: key, value: value)
            }
        }
        return self.templateFile().replacingOccurrences(of: "{{lo-script-content}}",
                                                        with: content)
    }

    func comment(from: String) -> String {
        switch device {
        case .ios:
            return "\n// \(from)\n\n"
        case .android:
            return "\n<!-- \(from) -->\n"
        }
    }

    func lineFrom(key: String, value: String) -> String {
        switch self.device {
        case .ios:
            return "\"\(key)\" = \"\(value)\";\n"
        case .android:
            return "<string name=\"\(key)\">\(value)</string>\n"
        }
    }

    func templateFile() -> String {
        switch self.device {
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
}
//
//  Sheet.swift
//  Lo-Script
//
//  Created by Sergio.Lopez on 1/2/20.
//  Copyright © 2020 Sergio.Lopez. All rights reserved.
//

import Foundation

struct Sheet {

    struct Row {
        enum Category {
            case comment(String)
            case translation(String, String)
        }

        let type: Category
    }

    let content: String
    let device: Device
    let languages: [String]
    var languagesDictionary: [String: [Row]] = [:]

    static let rowDelimiterCharacter = "\r\n"
    static let columnDelimiterCharacter = "\t"

    init(fromURL url: URL, device: Device) {
        self.content = try! String(contentsOf: url)
        self.device = device
        self.languages = SheetParser(content: content).getLanguages()

        languages.forEach { language in
            var rows: [Row] = []

            var foundStartingPoint = false

            let index = languages.firstIndex(of: language)!
            let keyToIgnore = device == Device.ios ? "_android" : "_ios"
            let lines = self.content.components(separatedBy: Sheet.rowDelimiterCharacter)

            lines.forEach { line in
                let values = line.components(separatedBy: Sheet.columnDelimiterCharacter)
                let firstValue = values.first!
                
                if !firstValue.contains(keyToIgnore) {
                    if firstValue == "[key]" {
                        foundStartingPoint = true
                    } else if foundStartingPoint {
                        if firstValue == "[COMMENT]" {
                            rows.append(Sheet.Row(type: .comment(values[index + 1])))
                        } else if !firstValue.contains("[") {
                            rows.append(Sheet.Row(type: .translation(firstValue, values[index + 1])))
                        }
                    }
                }
            }
            languagesDictionary[language] = rows
        }
    }

    func getLanguages() -> [String] {
        let lines = self.content.components(separatedBy: Sheet.rowDelimiterCharacter)
        guard let languageLine = lines.first(where: { $0.contains("[key]") }) else { return [] }
        let components = languageLine.components(separatedBy: Sheet.columnDelimiterCharacter)
        let languages = Array(components.dropFirst())
        return languages
    }
    
    func toStringFiles() -> [StringFile] {
        var stringFiles: [StringFile] = []
        self.languages.forEach { language in
            let file = StringFile(rows: self.languagesDictionary[language]!, device: device, language: language)
            stringFiles.append(file)
        }
        return stringFiles
    }

    func toConstants() -> String {

        let rows = self.languagesDictionary[self.languagesDictionary.keys.first!]!

        let template = """
        // Automatically Generated - DO NOT modify manually - use lo-script instead.

        // swiftlint:disable:this

        import Foundation
        {{lo-script-content}}
        """

        // Generate Content
        var content = ""

        rows.forEach { row in
            switch row.type {
            case .comment(let comment):
                content += "\n// \(comment.capitalized)\n\n"
            case .translation(let key, _):
                let upperCaseKey = key.split(separator: "_").map { $0.capitalized }.joined()
                content += "let kLocale\(upperCaseKey): String = { return NSLocalizedString(\"\(key)\", comment: \"\") }()\n"
            }
        }

        return template.replacingOccurrences(of: "{{lo-script-content}}", with: content)
    }
}

struct SheetParser {
    let content: String

    func getLanguages() -> [String] {
        let lines = self.content.components(separatedBy: Sheet.rowDelimiterCharacter)
        guard let languageLine = lines.first(where: { $0.contains("[key]") }) else { return [] }
        let components = languageLine.components(separatedBy: Sheet.columnDelimiterCharacter)
        let languages = Array(components.dropFirst())
        return languages
    }
}
//
//  main.swift
//  Lo-Script
//
//  Created by Sergio.Lopez on 1/2/20.
//  Copyright © 2020 Sergio.Lopez. All rights reserved.
//

/*
 Run command in terminal with:
 > swift lo-script.swift sheetURL device

 sheetURL: You need to create a sharing link of the google sheet so only people with that link can download the sheet. You must append to the url "/export?format=tsv" or "export?format=tsv&sheet=0" if the sheet has more pages
  Example:  https://docs.google.com/spreadsheets/d/1GbcR_lfekamj2DKWNIXSABVm-V3wLvx6Z9Wy4B1Qrd0/export?format=tsv&sheet=0

 device: "ios" or "android"
 */

import Foundation

fputs("✏️  Generating...", stderr)

let googleSheetURL = CommandLine.arguments[1]
let device = CommandLine.arguments[2].lowercased() == Device.android.rawValue ? Device.android : Device.ios

let sheet = Sheet(fromURL: URL(string: googleSheetURL)!, device: device)

// Convert sheet to string files
sheet.toStringFiles().forEach { $0.save() }

if device == .ios {
    // Create Constants file
    let constants = sheet.toConstants()
    FileHelper().save(constants, path: "./output/", filename: "LocalizableConstants.swift")
}

fputs("\n Finished 👍\n\n", stderr)
