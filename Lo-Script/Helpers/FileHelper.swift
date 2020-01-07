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
