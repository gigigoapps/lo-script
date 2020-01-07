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

        // swiftlint:disable identifier_name
        // swiftlint:disable file_length

        import Foundation

        {{lo-script-content}}

        // swiftlint:enable identifier_name
        // swiftlint:enable file_length
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
