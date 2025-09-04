//
//  ContentView.swift
//  AI Video Editor
//
//  Created by Abdur-Rahman Rana on 2025-09-01.
//

import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import AVFoundation
import Combine
import AVKit

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
            
            PlaybackView(viewModel: viewModel)
            
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
            document: ProjectDocument(engine: viewModel.engine),
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

struct PlaybackView: View {
    @ObservedObject var viewModel: TimelineViewModel
    // The player is now owned by the ViewModel. The view just displays it.

    var body: some View {
        VStack {
            VideoPlayerContainer(player: viewModel.player) // Use viewModel's player
                .aspectRatio(16/9, contentMode: .fit)
                .background(Color.black)
                .cornerRadius(8)
                .onChange(of: viewModel.clips) { _ in
                    // The VM will handle rebuilding its own player's queue
                    viewModel.rebuildPlayerQueue()
                }

            HStack {
                Button(action: {
                    viewModel.seekToBeginning()
                }) {
                    Image(systemName: "backward.to.start.fill")
                }
                
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                
                Button(action: {
                    viewModel.seekToEnd()
                }) {
                    Image(systemName: "forward.to.end.fill")
                }
                
                Text(formatDuration(viewModel.playbackTime))
                    .font(.system(.body, design: .monospaced))
                
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    private func formatDuration(_ milliseconds: UInt64) -> String {
        let totalSeconds = Double(milliseconds) / 1000
        let minutes = Int(totalSeconds / 60)
        let seconds = Int(totalSeconds) % 60
        let ms = Int(milliseconds) % 1000
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
    }
}

struct VideoPlayerContainer: NSViewRepresentable {
    var player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

class TimelineViewModel: ObservableObject {
    let engine = TimelineEngine()
    let player = AVQueuePlayer() // The VM now owns the player
    @Published var clips: [Clip] = []
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var showFileImporter = false
    @Published var showProjectOpener = false
    @Published var showProjectSaver = false
    @Published var projectName: String?
    @Published var hasUnsavedChanges = false
    
    // Playback State
    @Published var isPlaying = false
    @Published var playbackTime: UInt64 = 0
    
    private var timeObserver: Any? // For observing player state
    
    var currentProjectPath: String? {
        // The Rust engine is the single source of truth for the path.
        engine.getCurrentFilePath()
    }
    var currentProjectURL: URL?
    
    private static let directoryBookmarkKey = "projectDirectoryBookmark"
    
    var totalDuration: UInt64 {
        clips.reduce(0) { $0 + $1.duration }
    }
    
    init() {
        refreshClips()
        updateProjectInfo()
        setupPlayerObservers()
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
    
    // MARK: - Project Management
    
    func newProject() {
        _ = engine.newProject()
        refreshClips()
        updateProjectInfo()
        currentProjectURL = nil
        thumbnails.removeAll()
        
        // Reset playback
        engine.pause()
        engine.seek(to: 0)
    }
    
    func addClip(url: URL) {
        addClipAt(url: url, position: clips.count)
        updateProjectInfo()
        print("After adding clip - clips count: \(clips.count)")
    }
    
    func addClipAt(url: URL, position: Int) {
        let _ = url.startAccessingSecurityScopedResource()
        
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
        rebuildPlayerQueue()
        objectWillChange.send()
    }
    
    func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            
            for url in urls {
                let _ = url.startAccessingSecurityScopedResource()
                addClip(url: url)
            }
        } catch {
            // Handle error silently
        }
    }
    
    func cutClip(at index: Int, position: UInt64) {
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
        
        let existingThumbnails = self.thumbnails
        
        engine.cutClip(at: index, position: position)
        
        clips = engine.getAllClips()
        objectWillChange.send()
        
        if index < clips.count {
            let firstClipId = clips[index].id
            
            let urlString = clips[index].url
            if let url = URL(string: urlString) {
                let matchingThumbnail: NSImage?
                if let matchingKey = existingThumbnails.keys.first(where: { $0.hasPrefix(firstClipId) }) {
                    matchingThumbnail = existingThumbnails[matchingKey]
                } else {
                    matchingThumbnail = nil
                }
                
                if let thumbnail = matchingThumbnail {
                    self.thumbnails[firstClipId] = thumbnail
                    
                    if index + 1 < clips.count {
                        let secondClipId = clips[index + 1].id
                        self.thumbnails[secondClipId] = thumbnail
                    }
                    
                    objectWillChange.send()
                } else {
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
    
    // MARK: - Playback
    
    func seekToBeginning() {
        engine.seek(to: 0)
        rebuildPlayerQueue() // Rebuilding the queue is the most reliable way to restart
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        // Let togglePlayback handle playing
    }
    
    func seekToEnd() {
        engine.seek(to: totalDuration)
        player.pause()
        // The UI is driven by the engine, so this is sufficient.
        // togglePlayback will handle restarting if the user hits play.
    }
    
    private func setupPlayerObservers() {
        // This observer is now the single source of truth for syncing the UI and engine to the player's time.
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600), queue: .main) { [weak self] _ in
            guard let self = self else { return }
            
            // Update playing state
            let isPlayerPlaying = self.player.rate > 0
            if self.isPlaying != isPlayerPlaying {
                self.isPlaying = isPlayerPlaying
                if !isPlayerPlaying {
                    self.engine.pause()
                }
            }
            
            // Update engine time from player
            self.updateEngineTimeFromPlayer()
            
            // Update UI time from engine
            self.playbackTime = self.engine.getPlaybackTime()
        }
    }
    
    private func updateEngineTimeFromPlayer() {
        guard let currentItem = player.currentItem as? CustomPlayerItem else { return }

        // Find the index of the current clip using its unique ID.
        guard let currentClipIndex = clips.firstIndex(where: { $0.id == currentItem.clipID }) else {
            return
        }

        var timeBeforeCurrentClip: UInt64 = 0
        for i in 0..<currentClipIndex {
            timeBeforeCurrentClip += clips[i].duration
        }

        let currentTimeInSeconds = player.currentTime().seconds
        guard !currentTimeInSeconds.isNaN else { return }

        // The player's current time *is* the progress within the trimmed clip,
        // because we are playing an AVComposition.
        let progressInClip = UInt64(currentTimeInSeconds * 1000)

        let globalTime = timeBeforeCurrentClip + progressInClip
        engine.seek(to: globalTime)
    }
    
    func togglePlayback() {
        if player.rate > 0 {
            player.pause()
            engine.pause()
        } else {
            // If playback finished (current item is nil or at the end), restart from beginning.
            if player.currentItem == nil || engine.getPlaybackTime() >= totalDuration {
                seekToBeginning()
            }
            player.play()
            engine.play()
        }
    }
    
    func rebuildPlayerQueue() {
        let wasPlaying = player.rate > 0
        player.pause()
        player.removeAllItems()
        
        let playerItems = clips.compactMap { clip -> AVPlayerItem? in
            guard let url = URL(string: clip.url) else { return nil }

            let asset = AVURLAsset(url: url)
            let composition = AVMutableComposition()

            // Define the time range of the clip
            let startTime = CMTime(seconds: Double(clip.inPoint) / 1000.0, preferredTimescale: 600)
            let duration = CMTime(seconds: Double(clip.duration) / 1000.0, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, duration: duration)

            do {
                // Insert the desired time range of the source asset into the composition
                try composition.insertTimeRange(timeRange, of: asset, at: .zero)
            } catch {
                print("Error creating composition for clip \(clip.id): \(error)")
                return nil
            }

            // Create a custom player item that knows its clip ID
            return CustomPlayerItem(clipID: clip.id, asset: composition)
        }
        
        playerItems.forEach { player.insert($0, after: nil) }
        
        if wasPlaying {
            player.play()
        }
    }
    
    // Custom player item to hold our clip's unique ID
    class CustomPlayerItem: AVPlayerItem {
        let clipID: String

        init(clipID: String, asset: AVAsset) {
            self.clipID = clipID
            super.init(asset: asset, automaticallyLoadedAssetKeys: nil)
        }
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
    
    func saveProject() {
        print("TimelineViewModel.saveProject - Function called")
        
        // If we have a URL, save directly to it (Save).
        if let url = currentProjectURL {
            print("TimelineViewModel.saveProject - Existing URL found: \(url.path). Performing direct save.")
            
            guard let jsonString = engine.getProjectAsJson(),
                  let data = jsonString.data(using: .utf8) else {
                print("TimelineViewModel.saveProject - Failed to get project data from engine.")
                return
            }
            
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                try data.write(to: url, options: .atomic)
                print("TimelineViewModel.saveProject - Successfully wrote data to \(url.path).")
                
                engine.markAsSaved()
                updateProjectInfo()
                
            } catch {
                print("TimelineViewModel.saveProject - Error writing file: \(error.localizedDescription)")
            }
            
        } else {
            // If no URL, this is the first save, so show the "Save As" dialog.
            print("TimelineViewModel.saveProject - No existing URL. Showing file exporter.")
            showProjectSaver = true
        }
    }
    
    func handleProjectOpen(_ result: Result<[URL], Error>) {
        print("TimelineViewModel.handleProjectOpen - Function called")
        
        guard case .success(let urls) = result, let url = urls.first else {
            print("TimelineViewModel.handleProjectOpen - No URL provided or error.")
            return
        }
        
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("TimelineViewModel.handleProjectOpen - Could not decode data to string.")
                return
            }
            
            if engine.loadProject(fromJson: jsonString) {
                engine.setCurrentFilePath(url.path)
                
                self.currentProjectURL = url
                
                refreshClips()
                updateProjectInfo()
                regenerateAllThumbnails()
                print("TimelineViewModel.handleProjectOpen - Project loaded successfully from \(url.path)")
            } else {
                print("TimelineViewModel.handleProjectOpen - Engine failed to load project from JSON.")
            }
        } catch {
            print("TimelineViewModel.handleProjectOpen - Error reading file: \(error)")
        }
    }
    
    func handleProjectSave(_ result: Result<URL, Error>) {
        print("TimelineViewModel.handleProjectSave - Function called")
        
        switch result {
        case .success(let url):
            print("TimelineViewModel.handleProjectSave - FileDocument saved to URL: \(url.path)")
            engine.setCurrentFilePath(url.path)
            engine.markAsSaved()
            
            self.currentProjectURL = url
            updateProjectInfo()
            
        case .failure(let error):
            print("TimelineViewModel.handleProjectSave - Save operation ended with result: \(error.localizedDescription)")
        }
    }
    
    private func regenerateAllThumbnails() {
        thumbnails.removeAll()
        for clip in clips {
            if let clipUrl = URL(string: clip.url) {
                generateThumbnail(for: clipUrl, clipId: clip.id)
            }
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
    
    var jsonData: Data
    
    init(engine: TimelineEngine) {
        if let jsonString = engine.getProjectAsJson() {
            self.jsonData = jsonString.data(using: .utf8) ?? Data()
        } else {
            self.jsonData = Data()
        }
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.jsonData = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: jsonData)
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

