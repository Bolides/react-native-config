//
//  EnvironmentFiles.swift
//  PrepareReactNativeconfig
//
//  Created by Stijn on 15/02/2019.
//  Copyright © 2019 Pedro Belo. All rights reserved.
//

import Foundation
import SignPost
import ZFile

public struct Disk {
    
    // MARK: - Variables
    
    public let inputJSON: Input
    public let reactNativeFolder: FolderProtocol
    public let reactNativeConfigSwiftSourcesFolder: FolderProtocol
    public let androidFolder: FolderProtocol
    public let iosFolder: FolderProtocol
    
    public let iOS: Output
    public let android: Output
    
    public let code: Output.Code
    
    public let signPost: SignPostProtocol
    
    // MARK: - Structs
    
    public struct FileName {
        
        public struct JSON {
            static let debug = ".env.debug.json"
            static let release = ".env.release.json"
            static var local = ".env.local.json"
        }
        
    }
    
    public struct Input {
        public let debug: FileProtocol
        public let release: FileProtocol
        public let local: FileProtocol?
    }
    
    public struct Output {
        public let debug: FileProtocol
        public let release: FileProtocol
        public let local: FileProtocol?
        
        public struct Code {
            public let configurationWorkerFile: FileProtocol
            public let infoPlist: FileProtocol
            public let currentBuild: FileProtocol
        }
    }
    
    // MARK: - Init
    
    public init(reactNativeFolder: FolderProtocol, signPost: SignPostProtocol = SignPost.shared, currentFolder: FolderProtocol = FileSystem.shared.currentFolder) throws {
        
        self.signPost = signPost
                
        var debugJSON: FileProtocol!
        var releaseJSON: FileProtocol!
        var localJSON: FileProtocol?
        
        var androidFolder: FolderProtocol!
        var iosFolder: FolderProtocol!
        
        debugJSON = try reactNativeFolder.file(named: Disk.FileName.JSON.debug)
        releaseJSON = try reactNativeFolder.file(named: Disk.FileName.JSON.release)
        do { localJSON = try reactNativeFolder.file(named: Disk.FileName.JSON.local) } catch { signPost.message("💁🏻‍♂️ If you would like you can add \(Disk.FileName.JSON.local) to have a local config. Ignoring for now") }
        iosFolder = try reactNativeFolder.subfolder(named: "/Carthage/Checkouts/react-native-config/ios")
        androidFolder = try reactNativeFolder.subfolder(named: "android")
        
        reactNativeConfigSwiftSourcesFolder = try iosFolder.subfolder(named: "ReactNativeConfigSwift")
        
        self.inputJSON = Input(
            debug: debugJSON,
            release: releaseJSON,
            local: localJSON
        )
        
        self.androidFolder = androidFolder
        self.iosFolder = iosFolder
        self.reactNativeFolder = reactNativeFolder
        
        var localXconfigFile: FileProtocol?
        var localAndroidConfigurationFile: FileProtocol?
        
        if localJSON != nil {
            localXconfigFile = try iosFolder.createFileIfNeeded(named: "Local.xcconfig")
            localAndroidConfigurationFile = try androidFolder.createFileIfNeeded(named: ".env.local")
        } else {
            localXconfigFile = nil
            localAndroidConfigurationFile = nil
        }
        
        iOS = Output(
            debug: try iosFolder.createFileIfNeeded(named: "Debug.xcconfig"),
            release: try iosFolder.createFileIfNeeded(named: "Release.xcconfig"),
            local: localXconfigFile
        )
        
        android = Output(
            debug: try androidFolder.createFileIfNeeded(named: ".env.debug"),
            release: try androidFolder.createFileIfNeeded(named: ".env.release"),
            local: localAndroidConfigurationFile
        )
        
        code = Output.Code(
            configurationWorkerFile: try reactNativeConfigSwiftSourcesFolder.createFileIfNeeded(named: "CurrentBuildConfigurationWorker.swift"),
            infoPlist: try iosFolder.subfolder(named: "ReactNativeConfigSwift").createFileIfNeeded(named: "Info.plist"),
            currentBuild: try reactNativeConfigSwiftSourcesFolder.createFileIfNeeded(named: "CurrentBuildConfiguration.swift")
        )
        
    }
    
}
