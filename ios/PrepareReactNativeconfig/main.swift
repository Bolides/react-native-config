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

SignPost.shared.message("🚀 ReactNativeConfig main.swift\nExecuted at path \(currentFolder.path)\n...")
let envFileName_debug = ".env.debug"
let envFileName_release = ".env.release"

do {
    
    var reactNativeFolder = try currentFolder.parentFolder()
    
    var environmentFile_debug: FileProtocol!
    var environmentFile_release: FileProtocol!

    var iosFolder: FolderProtocol!
    
    do {
        SignPost.shared.verbose("PrepareReactNativeconfig run from post install in node_modules folder")
        environmentFile_debug = try reactNativeFolder.file(named: envFileName_debug)
        environmentFile_release = try reactNativeFolder.file(named: envFileName_release)
        iosFolder = try reactNativeFolder.subfolder(named: "/Carthage/Checkouts/react-native-config/ios")

    } catch {
        
        reactNativeFolder = try reactNativeFolder.parentFolder().parentFolder().parentFolder()
        
        SignPost.shared.verbose("PrepareReactNativeconfig run from building in the carthage checkouts folder")
        environmentFile_debug = try reactNativeFolder.file(named: envFileName_debug)
        environmentFile_release = try reactNativeFolder.file(named: envFileName_release)
        iosFolder = currentFolder
    }
    
    let frameworkSwiftFolder = try iosFolder.subfolder(named: "ReactNativeConfigSwift")
    
    let generatedEnvironmentSwiftFile = try frameworkSwiftFolder.createFileIfNeeded(named: "Environment.swift")
    let generatedPlistFile = try iosFolder.subfolder(named: "ReactNativeConfigSwift").file(named: "Info.plist")
    let generatedPlistSwiftFile = try frameworkSwiftFolder.createFileIfNeeded(named: "Plist.swift")
    
    let debugXconfigFile = try iosFolder.createFileIfNeeded(named: "Debug.xcconfig")
    try debugXconfigFile.write(string: try environmentFile_debug.readAsString())
    
    let releaseXconfigFile = try iosFolder.createFileIfNeeded(named: "Release.xcconfig")
    try releaseXconfigFile.write(string: try environmentFile_release.readAsString())
    
    SignPost.shared.message("🚀 extraction constants from path \(environmentFile_debug.path)\n...")
    
    let text: [(case: String, value: String, plistVar: String, xmlEntry: String)] = try environmentFile_debug.readAllLines().compactMap { textLine in
        let components = textLine.components(separatedBy: "=")
        
        guard
            components.count == 2,
            let key = components.first,
            let value = components.last else {
                return nil
        }
    
        
        return (
            case: "  case \(key)",
            value: "\(key): \"\(value)\"",
            plistVar: " public let \(key): String",
            xmlEntry: """
            <key>\(key)</key>
            <string>$(\(key))</string>
            """
        )
    }
    
    let allConStants: String = text.map { $0.value }.joined(separator: "\n")
    let allCases: String = text.map { $0.case }.joined(separator: "\n")
    
    
    SignPost.shared.verbose("Writing environment variables to swift files and plist")
    
    let swiftLines = """
    //
    //  Environment.swift
    //  ReactNativeConfigSwift
    //
    //  Created by Stijn on 29/01/2019.
    //  Copyright © 2019 Pedro Belo. All rights reserved.
    //

    import Foundation

    //⚠️ File is generated and ignored in git. To change it change /PrepareReactNativeconfig/main.swift

    @objc public class Environment: NSObject {
        
        @objc public class func allValuesDictionary() -> [String : String] {
            
            var dict = [String : String]()
            
             Environment.allConstants.forEach { _case in
                dict[_case.key.rawValue] = _case.value
            }
            return dict
        }
       
    public static let allConstants: [Environment.Case: String] = [\(allConStants)]
        
        public enum Case: String, CaseIterable {
        
            \(allCases)
    
        }
        
    }

    """
   
    try generatedEnvironmentSwiftFile.write(data: swiftLines.data(using: .utf8)!)
    
    let plistVar: String = text.map { $0.plistVar }.joined(separator: "\n")
    
    let plistLinesSwift = """
    //
    //  EnvironmentCustomPlist.swift
    //  ReactNativeConfigSwift
    //
    //  Created by Stijn on 30/01/2019.
    //  Copyright © 2019 Pedro Belo. All rights reserved.
    //

    import Foundation

    //⚠️ File is generated and ignored in git. To change it change /PrepareReactNativeconfig/main.swift

    public struct EnvironmentPlist: Codable {
        
        // These are the normal plist things

        public let CFBundleDevelopmentRegion: String
        public let CFBundleExecutable: String
        public let CFBundleIdentifier: String
        public let CFBundleInfoDictionaryVersion: String
        public let CFBundleName: String
        public let CFBundlePackageType: String
        public let CFBundleShortVersionString: String
        public let CFBundleVersion: String
        
        // Custom plist properties are added here
        \(plistVar)
    
    }
    """
    try generatedPlistSwiftFile.write(string: plistLinesSwift)
    
    let plistLinesXmlText: String = text.map { $0.xmlEntry }.joined(separator: "\n")
    
    let plistLinesXml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>CFBundleDevelopmentRegion</key>
        <string>$(DEVELOPMENT_LANGUAGE)</string>
        <key>CFBundleExecutable</key>
        <string>$(EXECUTABLE_NAME)</string>
        <key>CFBundleIdentifier</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleInfoDictionaryVersion</key>
        <string>6.0</string>
        <key>CFBundleName</key>
        <string>$(PRODUCT_NAME)</string>
        <key>CFBundlePackageType</key>
        <string>FMWK</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundleVersion</key>
        <string>$(CURRENT_PROJECT_VERSION)</string>
        \(plistLinesXmlText)
    </dict>
    </plist>
    """
    
    try generatedPlistFile.write(string: plistLinesXml)
    SignPost.shared.message("🚀 ReactNativeConfig main.swift ✅")
    
    exit(EXIT_SUCCESS)
} catch {
    SignPost.shared.error("""
        ❌
        Could not find '\(envFileName_release)' or/and '\(envFileName_debug)' file in your root React Native project.
        The error was:
        \(error)
        ❌
        ♥️ Fix it by adding .env file to root with `API_URL=https://myapi.com` or more
        """
    )
    exit(EXIT_FAILURE)
}

