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
