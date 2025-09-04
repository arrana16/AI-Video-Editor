//
//  ContentView.swift
//  AI Video Editor
//
//  Created by Abdur-Rahman Rana on 2025-09-01.
//

import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import AVFoundation

struct ContentView: View {
    @StateObject private var viewModel = TimelineViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AI Video Editor")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Project name display
            if let projectName = viewModel.projectName {
                HStack {
                    Text(projectName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if viewModel.hasUnsavedChanges {
                        Text("•")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            HStack {
                Button("New Project") {
                    viewModel.newProject()
                }
                .buttonStyle(.bordered)
                
                Button("Open Project") {
                    viewModel.showProjectOpener = true
                }
                .buttonStyle(.bordered)
                
                Button("Save Project") {
                    if viewModel.currentProjectPath != nil {
                        viewModel.saveProject()
                    } else {
                        viewModel.showProjectSaver = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.clips.isEmpty)
                
                Button("Save As...") {
                    viewModel.showProjectSaver = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.clips.isEmpty)
                
                Spacer()
                
                Button("Add Media Files") {
                    viewModel.showFileImporter = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Timeline display with file drop zone
            ScrollView(.horizontal, showsIndicators: true) {
                if viewModel.clips.isEmpty {
                    EmptyTimelineView(viewModel: viewModel)
                } else {
                    TimelineView(viewModel: viewModel)
                }
            }
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            
            // Timeline information
            VStack(alignment: .leading) {
                Text("Timeline Info:")
                    .font(.headline)
                
                Text("Clips: \(viewModel.clips.count)")
                Text("Total Duration: \(formatDuration(viewModel.totalDuration))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.6))
            .cornerRadius(8)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 400) // Increased width for new buttons
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.movie, .video, .audiovisualContent],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImport(result)
        }
        .fileImporter(
            isPresented: $viewModel.showProjectOpener,
            allowedContentTypes: [UTType(filenameExtension: "ave")!],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleProjectOpen(result)
        }
        .fileExporter(
            isPresented: $viewModel.showProjectSaver,
            document: ProjectDocument(content: ""),
            contentType: UTType(filenameExtension: "ave")!,
            defaultFilename: viewModel.projectName ?? "Untitled Project"
        ) { result in
            viewModel.handleProjectSave(result)
        }
        // Add direct file drop support to the whole view
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers -> Bool in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                        DispatchQueue.main.async {
                            if let url = urlData as? URL {
                                viewModel.addClip(url: url)
                            } else if let data = urlData as? Data, let urlString = String(data: data, encoding: .utf8), let url = URL(string: urlString) {
                                viewModel.addClip(url: url)
                            }
                        }
                    }
                }
            }
            
            return true
        }
        .onAppear {
            // Listen for file drop notifications from the app delegate
            NotificationCenter.default.addObserver(forName: Notification.Name("OpenURLs"), object: nil, queue: .main) { notification in
                if let urls = notification.userInfo?["urls"] as? [URL] {
                    for url in urls {
                        self.viewModel.addClip(url: url)
                    }
                }
            }
        }
    }
    
    private func formatDuration(_ milliseconds: UInt64) -> String {
        let totalSeconds = Double(milliseconds) / 1000
        let minutes = Int(totalSeconds / 60)
        let seconds = Int(totalSeconds) % 60
        let ms = Int(milliseconds) % 1000
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
    }
}

// Empty timeline with file drop support
struct EmptyTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @State private var isDropTargeted = false
    
    var body: some View {
        ZStack {
            Text("Drop media files here")
                .foregroundColor(.secondary)
                .frame(height: 100)
                .frame(minWidth: 300)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.windowBackgroundColor).opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDropTargeted ? Color.blue : Color.gray.opacity(0.3), 
                                        lineWidth: isDropTargeted ? 2 : 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            return handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    DispatchQueue.main.async {
                        guard let urlData = urlData else {
                            return
                        }
                        
                        // Handle different types of URL data
                        if let url = urlData as? URL {
                            self.viewModel.addClip(url: url)
                        } else if let data = urlData as? Data, let urlString = String(data: data, encoding: .utf8) {
                            if let url = URL(string: urlString) {
                                self.viewModel.addClip(url: url)
                            }
                        } else if let urlString = urlData as? String {
                            if let url = URL(string: urlString) {
                                self.viewModel.addClip(url: url)
                            }
                        }
                    }
                }
                return true
            }
        }
        
        return false
    }
}

// Separate TimelineView to handle the clips
struct TimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @State private var draggingClipIndex: Int? = nil
    @State private var draggedItemLocation: CGPoint? = nil
    @State private var dropTargetIndex: Int? = nil
    @State private var isDropTargeted = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(viewModel.clips.indices, id: \.self) { index in
                    ClipView(
                        clip: viewModel.clips[index], 
                        index: index,
                        thumbnail: viewModel.thumbnails[viewModel.clips[index].id],
                        isBeingDragged: draggingClipIndex == index,
                        isDropTarget: dropTargetIndex == index,
                        viewModel: viewModel, // Pass the actual view model instance
                        onRemove: { idx in
                            viewModel.removeClip(at: idx)
                        }
                    )
                    .contentShape(Rectangle()) // Make the entire area draggable
                    .onDrag {
                        // Start dragging
                        self.draggingClipIndex = index
                        return NSItemProvider(object: "\(index)" as NSString)
                    }
                    .onDrop(of: [UTType.text, UTType.fileURL, UTType.movie, UTType.video], isTargeted: $isDropTargeted) { providers in
                        // First check if we're handling a clip drag operation
                        for provider in providers where provider.canLoadObject(ofClass: NSString.self) {
                            provider.loadObject(ofClass: NSString.self) { object, error in
                                guard let string = object as? NSString,
                                      let sourceIndex = Int(string as String),
                                      sourceIndex != index else { return }
                                
                                DispatchQueue.main.async {
                                    self.dropTargetIndex = index
                                    // Execute the move with a small delay to allow visual feedback
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        viewModel.moveClip(from: sourceIndex, to: index)
                                        self.draggingClipIndex = nil
                                        self.dropTargetIndex = nil
                                    }
                                }
                            }
                            return true
                        }
                        
                        // If it's not a clip, check if it's a file
                        return handleFileDrop(providers: providers, targetIndex: index)
                    }
                }
            }
            .padding(.vertical)
            .frame(minHeight: 100)
            .background(Color(.windowBackgroundColor))
            .onDrop(of: [UTType.fileURL, UTType.movie, UTType.video], isTargeted: $isDropTargeted) { providers in
                // Handle dropping files at the end of the timeline
                return handleFileDrop(providers: providers, targetIndex: viewModel.clips.count)
            }
        }
    }
    
    private func handleFileDrop(providers: [NSItemProvider], targetIndex: Int) -> Bool {
        var imported = false
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                    DispatchQueue.main.async {
                        guard let urlData = urlData else {
                            return
                        }
                        
                        // Handle different types of URL data
                        if let url = urlData as? URL {
                            self.viewModel.addClipAt(url: url, position: targetIndex)
                            imported = true
                        } else if let data = urlData as? Data, let urlString = String(data: data, encoding: .utf8) {
                            if let url = URL(string: urlString) {
                                self.viewModel.addClipAt(url: url, position: targetIndex)
                                imported = true
                            }
                        } else if let urlString = urlData as? String {
                            if let url = URL(string: urlString) {
                                self.viewModel.addClipAt(url: url, position: targetIndex)
                                imported = true
                            }
                        }
                    }
                }
            }
        }
        
        return imported
    }
}

struct ClipView: View {
    let clip: Clip
    let index: Int
    let thumbnail: NSImage?
    let isBeingDragged: Bool
    let isDropTarget: Bool
    let viewModel: TimelineViewModel // Add view model parameter
    let onRemove: (Int) -> Void
    
    // Add state for cut position
    @State private var isCutting: Bool = false
    @State private var cutPosition: Double = 0.5 // Default to middle
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: max(80, Double(clip.duration) / 50), height: 80)
                        .clipped()
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isDropTarget ? Color.blue.opacity(0.8) : Color.gray.opacity(0.5), lineWidth: isDropTarget ? 2 : 1)
                        )
                        .overlay(
                            Text(clip.id)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                                .padding(4),
                            alignment: .bottom
                        )
                        .overlay(
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.blue.opacity(0.7))
                                .cornerRadius(4),
                            alignment: .topLeading
                        )
                    
                    // Add cut indicator if in cutting mode
                    if isCutting {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 80)
                            .position(x: max(40, Double(clip.duration) / 50) * cutPosition, y: 40)
                            .overlay(
                                Text("Cut")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .cornerRadius(2)
                                    .position(x: max(40, Double(clip.duration) / 50) * cutPosition, y: 15)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.7))
                        .frame(width: max(80, Double(clip.duration) / 50), height: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isDropTarget ? Color.blue.opacity(0.8) : Color.clear, lineWidth: isDropTarget ? 2 : 0)
                        )
                        .overlay(
                            Text(clip.id)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                        )
                        .overlay(
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4),
                            alignment: .topLeading
                        )
                    
                    // Add cut indicator if in cutting mode
                    if isCutting {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: 80)
                            .position(x: max(40, Double(clip.duration) / 50) * cutPosition, y: 40)
                            .overlay(
                                Text("Cut")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.red)
                                    .cornerRadius(2)
                                    .position(x: max(40, Double(clip.duration) / 50) * cutPosition, y: 15)
                            )
                    }
                }
                
                // Existing remove button
                Button(action: {
                    onRemove(index)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                
                // Add cut button
                Button(action: {
                    isCutting.toggle()
                }) {
                    Image(systemName: isCutting ? "checkmark.circle.fill" : "scissors")
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .offset(x: -30)
                
                // Show confirm cut button when in cutting mode
                if isCutting {
                    Button(action: {
                        // Calculate the actual position in milliseconds
                        let cutTimeMs = UInt64(Double(clip.duration) * cutPosition) + clip.inPoint
                        
                        // Debugging output to verify cut position
                        print("Cutting clip \(clip.id) at position \(cutTimeMs)ms (in: \(clip.inPoint), out: \(clip.outPoint))")
                        
                        // Use the passed view model instance instead of the singleton
                        viewModel.cutClip(at: index, position: cutTimeMs)
                        isCutting = false
                    }) {
                        Text("Cut")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .offset(y: 40)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                isCutting ?
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let clipWidth = max(80, Double(clip.duration) / 50)
                            let newPosition = value.location.x / clipWidth
                            cutPosition = max(0.1, min(0.9, newPosition)) // Keep within 10-90% range
                        } : nil
            )
            .opacity(isBeingDragged ? 0.6 : 1.0)
            
            Text("\(formatDuration(clip.duration))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ milliseconds: UInt64) -> String {
        let totalSeconds = Double(milliseconds) / 1000
        let minutes = Int(totalSeconds / 60)
        let seconds = Int(totalSeconds) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class TimelineViewModel: ObservableObject {
    private let engine = TimelineEngine()
    @Published var clips: [Clip] = []
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var showFileImporter = false
    @Published var showProjectOpener = false
    @Published var showProjectSaver = false
    @Published var projectName: String?
    @Published var hasUnsavedChanges = false
    
    var currentProjectPath: String?
    
    private var fileAccessSecurityScopedResources: [URL: Bool] = [:]
    
    var totalDuration: UInt64 {
        clips.reduce(0) { $0 + $1.duration }
    }
    
    init() {
        refreshClips()
        updateProjectInfo()
    }
    
    func addClip(url: URL) {
        addClipAt(url: url, position: clips.count)
        updateProjectInfo()
        print("After adding clip - clips count: \(clips.count)")
    }
    
    func addClipAt(url: URL, position: Int) {
        let startedAccessing = url.startAccessingSecurityScopedResource()
        fileAccessSecurityScopedResources[url] = startedAccessing
        
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "bookmark-\(url.lastPathComponent)")
        } catch {
            // Continue even if bookmark creation fails
        }
        
        let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        let secureAsset = AVURLAsset(url: url, options: options)
        
        let id = url.lastPathComponent
        let clip = Clip(
            id: id,
            url: url.absoluteString,
            inPoint: 0,
            outPoint: 5000
        )
        
        let safePosition = min(position, clips.count)
        engine.addClip(clip, at: safePosition)
        refreshClips()
        
        generateThumbnail(for: url, clipId: id)
        
        Task {
            do {
                let duration = try await secureAsset.load("duration")
                if let cmTimeDuration = duration as? CMTime {
                    let durationMs = UInt64(CMTimeGetSeconds(cmTimeDuration) * 1000)
                    
                    if let index = self.clips.firstIndex(where: { $0.id == id }) {
                        let updatedClip = Clip(
                            id: id,
                            url: url.absoluteString,
                            inPoint: 0,
                            outPoint: durationMs
                        )
                        
                        DispatchQueue.main.async {
                            self.engine.removeClip(at: index)
                            self.engine.addClip(updatedClip, at: index)
                            self.refreshClips()
                        }
                    }
                }
            } catch {
                // Continue even if getting duration fails
            }
        }
    }
    
    func removeClip(at index: Int) {
        if index < clips.count {
            let clipId = clips[index].id
            engine.removeClip(at: index)
            refreshClips()
            updateProjectInfo()
            
            thumbnails.removeValue(forKey: clipId)
        }
    }
    
    func moveClip(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex < clips.count,
              destinationIndex < clips.count else {
            return
        }
        
        let clipToMove = clips[sourceIndex]
        engine.removeClip(at: sourceIndex)
        
        let adjustedDestIndex = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        engine.addClip(clipToMove, at: adjustedDestIndex)
        
        refreshClips()
    }
    
    func refreshClips() {
        clips = engine.getAllClips()
        objectWillChange.send()
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            
            for url in urls {
                let startedAccessing = url.startAccessingSecurityScopedResource()
                fileAccessSecurityScopedResources[url] = startedAccessing
                
                do {
                    let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: "bookmark-\(url.lastPathComponent)")
                } catch {
                    // Continue even if bookmark creation fails
                }
                
                addClip(url: url)
            }
        } catch {
            // Handle error silently
        }
    }
    
    func cutClip(at index: Int, position: UInt64) {
        // Verify the index and position values
        print("Current clips count: \(clips.count)")
        guard index < clips.count else {
            print("Cut failed: Index \(index) out of bounds (clips count: \(clips.count))")
            return
        }
        
        let clip = clips[index]
        guard position > clip.inPoint && position < clip.outPoint else {
            print("Cut failed: Position \(position) not within clip range (\(clip.inPoint)-\(clip.outPoint))")
            return
        }
        
        print("Cutting clip at index \(index): \(clip.id) at position \(position)")
        
        // Store existing thumbnails to reuse after cutting
        let existingThumbnails = self.thumbnails
        
        // Perform the cut in the Rust engine
        engine.cutClip(at: index, position: position)
        
        // Force a refresh of clips from the engine
        clips = engine.getAllClips()
        objectWillChange.send()
        
        // Manually update thumbnails for the new clips
        if index < clips.count {
            let firstClipId = clips[index].id
            
            // Get the URL for this clip (it's not optional, so no need for if let)
            let urlString = clips[index].url
            if let url = URL(string: urlString) {
                // Check if we already have a thumbnail for the source clip
                // Extract the base part of the ID (before any timestamp suffix)
                let originalClipIdComponents = firstClipId.split(separator: "-")
                let originalClipId = originalClipIdComponents.count > 0 ? String(originalClipIdComponents[0]) : ""
                
                // Find any thumbnail that has a key starting with the original clip ID
                let matchingThumbnail: NSImage?
                if let matchingKey = existingThumbnails.keys.first(where: { $0.hasPrefix(originalClipId) }) {
                    matchingThumbnail = existingThumbnails[matchingKey]
                } else {
                    matchingThumbnail = nil
                }
                
                // Use the existing thumbnail if available, otherwise generate a new one
                if let thumbnail = matchingThumbnail {
                    self.thumbnails[firstClipId] = thumbnail
                    
                    // Also set for the second clip if it exists
                    if index + 1 < clips.count {
                        let secondClipId = clips[index + 1].id
                        self.thumbnails[secondClipId] = thumbnail
                    }
                    
                    // Send change notification
                    objectWillChange.send()
                } else {
                    // Generate new thumbnails if needed
                    generateThumbnail(for: url, clipId: firstClipId)
                    
                    if index + 1 < clips.count {
                        let secondClipId = clips[index + 1].id
                        generateThumbnail(for: url, clipId: secondClipId)
                    }
                }
            }
        }
        
        print("After cut, clips count: \(clips.count)")
        updateProjectInfo()
    }
    
    private func generateThumbnail(for url: URL, clipId: String) {
        guard url.isFileURL && FileManager.default.fileExists(atPath: url.path) else {
            print("Cannot generate thumbnail: Invalid URL or file doesn't exist at \(url.path)")
            return
        }
        
        do {
            let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            let asset = AVURLAsset(url: url, options: options)
            
            asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
                var error: NSError?
                let status = asset.statusOfValue(forKey: "tracks", error: &error)
                
                if status == .failed {
                    print("Failed to load tracks for thumbnail: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                if status == .loaded {
                    let imageGenerator = AVAssetImageGenerator(asset: asset)
                    imageGenerator.appliesPreferredTrackTransform = true
                    imageGenerator.maximumSize = CGSize(width: 300, height: 300)
                    
                    // Get thumbnail from middle of clip for better representation
                    let duration = asset.duration.seconds
                    let time = CMTime(seconds: max(1, duration / 2), preferredTimescale: 60)
                    
                    print("Generating thumbnail for \(clipId) at \(time.seconds)s")
                    
                    imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, cgImage, _, result, error in
                        if let error = error {
                            print("Thumbnail generation error: \(error.localizedDescription)")
                        }
                        
                        if result == .succeeded, let cgImage = cgImage {
                            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            
                            DispatchQueue.main.async {
                                self?.thumbnails[clipId] = thumbnail
                                self?.objectWillChange.send()
                                print("Thumbnail generated for \(clipId)")
                            }
                        } else {
                            print("Failed to generate thumbnail: result=\(result), error=\(error?.localizedDescription ?? "nil")")
                        }
                    }
                }
            }
        } catch {
            print("Exception in thumbnail generation: \(error.localizedDescription)")
        }
    }
    
    func updateClipRange(at index: Int, inPoint: UInt64, outPoint: UInt64) {
        engine.updateClipRange(at: index, inPoint: inPoint, outPoint: outPoint)
        refreshClips()
    }
    
    deinit {
        for (url, didStartAccessing) in fileAccessSecurityScopedResources {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    // MARK: - Project Management
    
    func newProject() {
        _ = engine.newProject()
        refreshClips()
        updateProjectInfo()
        currentProjectPath = nil
        thumbnails.removeAll()
    }
    
    func saveProject() {
        guard let path = currentProjectPath else { return }
        if engine.saveProject(to: path) {
            updateProjectInfo()
            print("Project saved successfully to \(path)")
        } else {
            print("Failed to save project")
        }
    }
    
    func handleProjectOpen(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            
            let path = url.path
            if engine.loadProject(from: path) {
                currentProjectPath = path
                refreshClips()
                updateProjectInfo()
                
                // Clear existing thumbnails and regenerate for loaded clips
                thumbnails.removeAll()
                for clip in clips {
                    if let clipUrl = URL(string: clip.url) {
                        generateThumbnail(for: clipUrl, clipId: clip.id)
                    }
                }
                
                print("Project loaded successfully from \(path)")
            } else {
                print("Failed to load project from \(path)")
            }
        } catch {
            print("Error opening project: \(error)")
        }
    }
    
    func handleProjectSave(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            var path = url.path
            
            // Ensure .ave extension
            if !path.hasSuffix(".ave") {
                path += ".ave"
            }
            
            if engine.saveProject(to: path) {
                currentProjectPath = path
                updateProjectInfo()
                print("Project saved successfully to \(path)")
            } else {
                print("Failed to save project to \(path)")
            }
        } catch {
            print("Error saving project: \(error)")
        }
    }
    
    private func updateProjectInfo() {
        projectName = engine.getProjectName()
        hasUnsavedChanges = engine.hasUnsavedChanges()
    }
}

// Document wrapper for file export
struct ProjectDocument: FileDocument {
    static var readableContentTypes: [UTType] { [UTType(filenameExtension: "ave")!] }
    
    var content: String
    
    init(content: String) {
        self.content = content
    }
    
    init(configuration: ReadConfiguration) throws {
        content = ""
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

extension AVAsset {
    func load(_ propertyName: String) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            self.loadValuesAsynchronously(forKeys: [propertyName]) {
                var error: NSError? = nil
                let status = self.statusOfValue(forKey: propertyName, error: &error)
                
                switch status {
                case .loaded:
                    continuation.resume(returning: self.value(forKey: propertyName) as Any)
                case .failed:
                    continuation.resume(throwing: error ?? NSError(domain: "AVAssetErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to load \(propertyName)"]))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "AVAssetErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Cancelled loading \(propertyName)"]))
                default:
                    continuation.resume(throwing: NSError(domain: "AVAssetErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown status for \(propertyName)"]))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

