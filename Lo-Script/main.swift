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
