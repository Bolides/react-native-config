//
//  main.swift
//  PrepareReactNativeconfig
//
//  Created by Stijn on 29/01/2019.
//  Copyright © 2019 Pedro Belo. All rights reserved.
//

import Foundation
import ZFile
import SignPost

let currentFolder = FileSystem.shared.currentFolder
enum Error: Swift.Error {
    case noPrepareInSwiftFile
    case missingIOSFolder
}

do {
    SignPost.shared.message("🚀 ReactNativeConfig main.swift\nExecuted at path \(currentFolder.path)\n...")
    let envFileName = ".env"

    var reactNativeFolder = try currentFolder.parentFolder()
    
    var environmentFile: FileProtocol!
    var iosFolder: FolderProtocol!
    
    do {
        // This happens when running from post install in node_modules folder
        environmentFile = try reactNativeFolder.file(named: envFileName)
        iosFolder = try reactNativeFolder.subfolder(named: "/Carthage/Checkouts/react-native-config/ios")

    } catch {
        
        reactNativeFolder = try reactNativeFolder.parentFolder().parentFolder().parentFolder()
        
        // We run from building in the carthage checkouts folder
        environmentFile = try reactNativeFolder.file(named: envFileName)
        iosFolder = currentFolder
    }
    
    let sourcesFolder = try iosFolder.subfolder(named: "ReactNativeConfig")
    
    let generatedInfoPlistDotEnvFile = try sourcesFolder.createFileIfNeeded(named: "GeneratedInfoPlistDotEnv.h")
    let generatedDotEnvFile = try sourcesFolder.createFileIfNeeded(named: "GeneratedDotEnv.m")
    let generatedSwiftFile = try iosFolder.subfolder(named: "ReactNativeConfigSwift").createFileIfNeeded(named: "Environment.swift")
    
    SignPost.shared.message("🚀 extraction constants from path \(environmentFile.path)\n...")
    
    let text: [(info: String, dotEnv: String, swift: String)] = try environmentFile.readAllLines().compactMap { textLine in
        let components = textLine.components(separatedBy: "=")
        
        guard
            components.count == 2,
            let key = components.first,
            let value = components.last else {
                return nil
        }
        // #define __RN_CONFIG_API_URL  https://myapi.com
        // #define DOT_ENV @{ @"API_URL":@"https://myapi.com" };
        
        return (
            info: "#define __RN_CONFIG_\(key) \(value)",
            dotEnv: "#define DOT_ENV @{ @\"\(key)\":@\"\(value)\"};",
            swift: "    case \(key) = \"\(value)\""
        )
    }
    
    try generatedInfoPlistDotEnvFile.write(data: text.map { $0.info }.joined(separator: "\n").data(using: .utf8)!)
    try generatedDotEnvFile.write(data: text.map { $0.dotEnv }.joined(separator: "\n").data(using: .utf8)!)
    
    let headerSwift = """
    //
    //  Environment.swift
    //  ReactNativeConfigSwift
    //
    //  Created by Stijn on 29/01/2019.
    //  Copyright © 2019 Pedro Belo. All rights reserved.
    //

    import Foundation

    enum Environment: String, CaseIterable {
    """
    var swiftLines = [headerSwift]
    swiftLines.append(contentsOf: text.map { $0.swift })
    swiftLines.append("}")
    
    try generatedSwiftFile.write(data: swiftLines.joined(separator: "\n").data(using: .utf8)!)
    SignPost.shared.message("🚀 ReactNativeConfig main.swift ✅")
    
    exit(EXIT_SUCCESS)
} catch {
    SignPost.shared.error("""
        ❌
        Could not find '.env' file in your root React Native project.
        The error was:
        \(error)
        ❌
        ♥️ Fix it by adding .env file to root with `API_URL=https://myapi.com` or more
        """
    )
    exit(EXIT_FAILURE)
}

