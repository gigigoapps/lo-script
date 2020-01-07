//
//  Shell.swift
//  Lo-Script
//
//  Created by Sergio.Lopez on 1/2/20.
//  Copyright © 2020 Sergio.Lopez. All rights reserved.
//

import Foundation

// Allows to run a command line tool
struct Shell {
    @discardableResult
    func exec(_ args: String...) -> Int32 {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
        return task.terminationStatus
    }
}
