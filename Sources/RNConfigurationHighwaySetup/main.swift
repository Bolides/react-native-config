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
import Arguments
import Highway
import Terminal
import RNConfigurationPrepare
import SourceryWorker

let signPost = SignPost.shared

let xcbuild = XCBuild()
let highWay: Highway!
let highwayRunner: HighwayRunner!
let dispatchGroup = DispatchGroup()

func handleSourceryOutput(_ sourceryOutput: @escaping SourceryWorker.SyncOutput) { do { signPost.verbose("\(try sourceryOutput())") } catch { signPost.error("\(error)") } }
func handleTestOutput(_ testOutput: @escaping HighwayRunner.SyncTestOutput) { do { signPost.verbose("\(try testOutput())") } catch { signPost.error("\(error)") } }

do {
    let srcRoot = try File(path: #file).parentFolder().parentFolder().parentFolder()
    let dependecyService = DependencyService(in: srcRoot)
    let package = try Highway.package(for: srcRoot, dependencyService: dependecyService)
    highWay = try Highway(package:  (package: package, executable: "RNConfigurationHighwaySetup"), dependencyService: dependecyService, swiftPackageWithSourceryFolder: srcRoot)
    highwayRunner = HighwayRunner(highway: highWay, dispatchGroup: dispatchGroup)
    
    let prepareCode = try PrepareCode(reactNativeFolder: srcRoot)
    
    do {
        SignPost.shared.message("🏗 PREPARE **RNConfiguration** ...")

        try prepareCode.attempt()
        try highwayRunner.addGithooksPrePush()

        highwayRunner.runSourcery(handleSourceryOutput)
        
        dispatchGroup.notify(queue: DispatchQueue.main) {
           
            highwayRunner.runTests(handleTestOutput)
            dispatchGroup.wait()
            
            guard highwayRunner.errors?.count ?? 0 <= 0 else {
                SignPost.shared.error("""
                    ❌ PREPARE **RNConfiguration**
                    
                    \(highwayRunner.errors!)
                    
                    ❌
                    ♥️ Fix it by adding environment files
                    \(ConfigurationDisk.JSONFileName.allCases.map { "* \($0.rawValue)"}.joined(separator: "\n"))
                    """
                )
                exit(EXIT_FAILURE)
            }
            SignPost.shared.message("🏗 PREPARE **RNConfiguration** ✅")
            
            exit(EXIT_SUCCESS)
        }
       
        dispatchMain()
        
    }
    
   
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
