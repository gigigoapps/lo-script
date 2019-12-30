#!/bin/bash

# CONFIGURE:

# You need to create a sharing link of the google sheet so only people with that link can download the sheet. You must append to the url "/export?format=tsv" or "export?format=tsv&sheet=0" if the sheet has more pages
# Example:  https://docs.google.com/spreadsheets/d/1GbcR_lfekamj2DKWNIXSABVm-V3wLvx6Z9Wy4B1Qrd0/export?format=tsv&sheet=0

sheetURL="https://docs.google.com/spreadsheets/d/1GbcR_lfekamj2DKWNIXSABVm-V3wLvx6Z9Wy4B1Qrd0/export?format=tsv&sheet=0"

# ios / android
device="ios"


#####

swift lo-script.swift $sheetURL $device
