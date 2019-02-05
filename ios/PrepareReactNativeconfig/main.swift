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

let signPost = SignPost.shared
signPost.message("🚀 ReactNativeConfig main.swift\nExecuted at path \(currentFolder.path)\n...")
let envFileName_debug = ".env.debug.json"
let envFileName_release = ".env.release.json"
var envFileName_local = ".env.local.json"

do {
    
    var reactNativeFolder = try currentFolder.parentFolder()
    
    var environmentFile_debug: FileProtocol!
    var environmentFile_release: FileProtocol!
    var environmentFile_local: FileProtocol?

    var iosFolder: FolderProtocol!
    
    do {
        SignPost.shared.verbose("PrepareReactNativeconfig run from post install in node_modules folder")
        environmentFile_debug = try reactNativeFolder.file(named: envFileName_debug)
        environmentFile_release = try reactNativeFolder.file(named: envFileName_release)
        do { environmentFile_local = try reactNativeFolder.file(named: envFileName_local) } catch { signPost.message("💁🏻‍♂️ If you would like you can add \(envFileName_local) to have a local config. Ignoring for now") }
        iosFolder = try reactNativeFolder.subfolder(named: "/Carthage/Checkouts/react-native-config/ios")

    } catch {
        
        reactNativeFolder = try reactNativeFolder.parentFolder().parentFolder().parentFolder()
        
        SignPost.shared.verbose("PrepareReactNativeconfig run from building in the carthage checkouts folder")
        environmentFile_debug = try reactNativeFolder.file(named: envFileName_debug)
        environmentFile_release = try reactNativeFolder.file(named: envFileName_release)
        do { environmentFile_local = try reactNativeFolder.file(named: envFileName_local) } catch { signPost.message("💁🏻‍♂️ If you would like you can add \(envFileName_local) to have a local config. Ignoring for now") }

        iosFolder = currentFolder
    }
    
    let frameworkSwiftFolder = try iosFolder.subfolder(named: "ReactNativeConfigSwift")
    
    let generatedEnvironmentSwiftFile = try frameworkSwiftFolder.createFileIfNeeded(named: "Environment.swift")
    let generatedPlistFile = try iosFolder.subfolder(named: "ReactNativeConfigSwift").createFileIfNeeded(named: "Info.plist")
    let generatedPlistSwiftFile = try frameworkSwiftFolder.createFileIfNeeded(named: "Plist.swift")
    
    let debugXconfigFile = try iosFolder.createFileIfNeeded(named: "Debug.xcconfig")
    let env_debug: Env = try JSONDecoder().decode(Env.self, from:  try environmentFile_debug.read())

    try debugXconfigFile.write(string: try env_debug.xcconfigEntry())
    
    let releaseXconfigFile = try iosFolder.createFileIfNeeded(named: "Release.xcconfig")
    let env_release: Env = try JSONDecoder().decode(Env.self, from:  try environmentFile_release.read())

    try releaseXconfigFile.write(string: try env_release.xcconfigEntry())
    
    if let environmentFile_local = environmentFile_local {
        let localXconfigFile = try iosFolder.createFileIfNeeded(named: "Local.xcconfig")
        let env_local: Env = try JSONDecoder().decode(Env.self, from: try environmentFile_local.read())
        
        try localXconfigFile.write(string: try env_local.xcconfigEntry())

    }
    
    SignPost.shared.message("""
        🚀 Env read from
            \(environmentFile_debug!)
            \(environmentFile_release!)
        ...
        """
    )
    
    // Only 1 environment read is good. Values come form configuration files
    
    let text: [(case: String, plistVar: String, plistVarString: String, xmlEntry: String)] = env_debug.env.enumerated().compactMap {
        let key = $0.element.key
        let typedValue = $0.element.value.typedValue
        let swiftTypeString = typedValue.typeSwiftString
        let xmlType = typedValue.typePlistString
        
        return (
            case: "case \(key)",
            plistVar: "public let \(key): \(swiftTypeString)",
            plistVarString: "\(key): \\(\(key))",
            xmlEntry: """
            <key>\(key)</key>
            <\(xmlType)>$(\(key))</\(xmlType)>
            """
        )
    }
    
    let allCases: String = text
        .map { $0.case }
        .map {"      \($0)"}
        .joined(separator: "\n")
    
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

    /// ⚠️ File is generated and ignored in git. To change it change /PrepareReactNativeconfig/main.swift
    @objc public class Environment: NSObject {
        
        public enum Error: Swift.Error {
            case noInfoDictonary
            case infoDictionaryNotReadableAsDictionary
        }
        
        @objc public class func allValuesDictionary() throws -> [String : String] {
            
            var dict = [String : String]()
            
             try Environment.allConstants().forEach { _case in
                dict[_case.key.rawValue] = _case.value
            }
            return dict
        }
       
        /// All custom environment dependend keys that are added to the plist and in the dictionary
        @objc public func allCustomKeys() -> [String] {
            return Case.allCases.map { $0.rawValue }
        }
        
        /// Keys used in the plist of ReactNativeConfigSwift module when building for the selected configuration (Debug or Release)
        public enum Case: String, CaseIterable {
            
    \(allCases)
            
        }
        
        /// Plist containing custom variables that are set from the .env.debug.json or .env.release.json dependend on the configuration you build for.
        public static func plist() throws ->  Plist {
            
            guard let infoDict = Bundle(for: Environment.self).infoDictionary else {
                throw Error.noInfoDictonary
            }
            
            let data = try JSONSerialization.data(withJSONObject: infoDict, options: .prettyPrinted)
            
            return try JSONDecoder().decode(Plist.self, from: data)
        }
        
        /// If using swift use plist()
        /// In Objective-C you can access this dictionary containing all custom environment dependend keys.
        /// They are set from the .env.debug.json or .env.release.json dependend on the configuration you build for.
        public static func  allConstants() throws ->  [Environment.Case: String] {
            var result = [Case: String]()
            
            let plist = try Environment.plist()
            let data = try JSONEncoder().encode(plist)
            
            guard let dict: [String: String] = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? [String : String] else {
                throw Error.infoDictionaryNotReadableAsDictionary
            }
            
            dict.forEach {
                
                guard let key = Case(rawValue: $0.key) else {
                    return
                }
                result[key] = $0.value
            }
            
            return result
        }
        
        
    }

    """
   
    try generatedEnvironmentSwiftFile.write(data: swiftLines.data(using: .utf8)!)
    
    let plistVar: String = text
        .map { $0.plistVar }
        .map {"    \($0)"}
        .joined(separator: "\n")
    let plistVarString: String = text
        .map { $0.plistVarString }
        .map { "            * \($0)" }
        .joined(separator: "\n")
    
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

    public struct Plist: Codable, CustomStringConvertible {
        
        
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
        
        public var description: String {
            return \"""
            Environment Plist
    
            // Config variable of Framework ReactNativeConfigSwift
    
                * CFBundleDevelopmentRegion = \\(CFBundleDevelopmentRegion)
                * CFBundleExecutable = \\(CFBundleExecutable)
                * CFBundleIdentifier = \\(CFBundleIdentifier)
                * CFBundleInfoDictionaryVersion = \\(CFBundleInfoDictionaryVersion)
                * CFBundleName = \\(CFBundleName)
                * CFBundlePackageType = \\(CFBundlePackageType)
                * CFBundleShortVersionString = \\(CFBundleShortVersionString)
                * CFBundleVersion = \\(CFBundleVersion)
    
            // Custom environment dependend constants from .env.debug.json or .env.release.json 

    \(plistVarString)
            \"""
        }
    
    }
    
    """
    try generatedPlistSwiftFile.write(string: plistLinesSwift)
    
    let plistLinesXmlText: String = text
        .map { $0.xmlEntry }
        .map {"      \($0)"}
        .joined(separator: "\n")
    
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
    ❌ Prepare React Native Config
    
         \(error)
    
    ❌
        ♥️ Fix it by adding \(envFileName_debug) & \(envFileName_release) at <#react native#>/
    """
    )
    exit(EXIT_FAILURE)
}

