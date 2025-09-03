//
//  AI_Video_EditorApp.swift
//  AI Video Editor
//
//  Created by Abdur-Rahman Rana on 2025-09-01.
//

import SwiftUI

@main
struct AI_Video_EditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register for file types using NSPasteboard instead of NSApp
        let types: [NSPasteboard.PasteboardType] = [.fileURL]
        NSApp.windows.first?.contentView?.registerForDraggedTypes(types)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        // This will be called when files are opened via Finder or drag/drop to app icon
        print("App received URLs to open: \(urls)")
        
        // Post a notification that ContentView could listen for
        NotificationCenter.default.post(name: Notification.Name("OpenURLs"), object: nil, userInfo: ["urls": urls])
    }
}
