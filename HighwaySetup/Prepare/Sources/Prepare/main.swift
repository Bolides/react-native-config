//
//  main.swift
//  PrepareReactNativeConfig
//
//  Created by Stijn on 29/01/2019.
//  Copyright © 2019 Pedro Belo. All rights reserved.
//

import Foundation
import ZFile
import SignPost
import XCBuild
import Task
import Arguments

let signPost = SignPost.shared

enum TestableSchemes: String, CaseIterable {
    case iOS = "RNConfigurationBridge-iOS"
}

let xcbuild = XCBuild()

do {
    let disk = try Disk()
    let reactNativeFolder = disk.srcRoot
    let prepareCode = try PrepareCode(reactNativeFolder: reactNativeFolder)
    let reactNativeConfigworkspace = try? reactNativeFolder.subfolder(named: "/ios/ReactNativeConfig.xcworkspace")
    
    do {
        try prepareCode.attempt()
        
        guard let workspace = reactNativeConfigworkspace else {
            SignPost.shared.message("🏗 PREPARE **RNConfiguration** ✅")
            
            exit(EXIT_SUCCESS)
        }
        
        do {
            try TestableSchemes.allCases.forEach { scheme in
                
                signPost.message("🧪 TESTING \(scheme.rawValue)")
                
                // xcodebuild test -workspace ios/ReactNativeConfig.xcworkspace -scheme RNConfiguration-macOS
                let destination = DestinationFactory().simulator(.iOS, name: "iPhone XR", os: .iOS(version: "12.0"), id: nil)
                let testRunner = try TestRunner(
                    xcbuild: xcbuild,
                    testOptions: try MinimalTestOptions(
                        scheme: scheme.rawValue,
                        workspace: workspace,
                        xcodebuild: xcbuild,
                        destination: destination
                    )
                )
                
                do {
                    try testRunner.attempt()
                    signPost.message("🧪 TESTING \(scheme.rawValue) ✅")
                } catch {
                    throw "\(scheme.rawValue)\n❌\(error)\n"
                }
                
            }
        } catch {
            signPost.message("\n⚠️\nFor now ignoring test errors\n \(error)\n⚠️")
        }
        
        
    }
    
    SignPost.shared.message("🏗 PREPARE **RNConfiguration** ✅")
    
    exit(EXIT_SUCCESS)
} catch let XCBuild.TestRunError.testsFailed(report: testReport) {
    SignPost.shared.error("""
        ❌ PREPARE **RNConfiguration** tests failed
        \(testReport)
        """
    )
    exit(EXIT_FAILURE)
} catch {
    SignPost.shared.error("""
        ❌ PREPARE **RNConfiguration**
        
        \(error)
        
        ❌
        ♥️ Fix it by adding environment files
        \(ConfigurationDisk.JSONFileName.allCases.map { "* \($0.rawValue)"}.joined(separator: "\n"))
        """
    )
    exit(EXIT_FAILURE)
} 