import Foundation
import AVFoundation
import Combine

/// Manages audio queue with seamless transitions, crossfading, and prebuffering
final class AudioQueueManager: ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var currentTrack: Track?
    @Published private(set) var nextTrack: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var queueHistory: [Track] = []
    @Published private(set) var isShuffleEnabled: Bool = false
    @Published private(set) var crossfadeDuration: TimeInterval = 3.0
    
    private let audioEngine: AudioEngine
    private var currentPlayer: AVAudioPlayerNode?
    private var nextPlayer: AVAudioPlayerNode?
    private var currentFile: AVAudioFile?
    private var nextFile: AVAudioFile?
    
    private var crossfadeTimer: Timer?
    private var preloadTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    private let queuePersistence = QueuePersistence()
    private let prebufferSize: Int = 3 // Number of tracks to prebuffer
    private var prebufferedFiles: [URL: AVAudioFile] = [:]
    
    // MARK: - Queue State
    
    private struct QueueState {
        var originalQueue: [Track] = []
        var shuffledIndices: [Int] = []
        var currentIndex: Int = 0
    }
    
    private var queueState = QueueState()
    
    // MARK: - Initialization
    
    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
        setupObservers()
        restoreQueue()
    }
    
    // MARK: - Queue Management
    
    /// Add a track to the queue
    func addToQueue(_ track: Track, at index: Int? = nil) {
        if let index = index, index <= queue.count {
            queue.insert(track, at: index)
            queueState.originalQueue.insert(track, at: index)
        } else {
            queue.append(track)
            queueState.originalQueue.append(track)
        }
        
        if isShuffleEnabled {
            regenerateShuffledIndices()
        }
        
        saveQueue()
        prebufferUpcomingTracks()
    }
    
    /// Add multiple tracks to the queue
    func addToQueue(_ tracks: [Track]) {
        queue.append(contentsOf: tracks)
        queueState.originalQueue.append(contentsOf: tracks)
        
        if isShuffleEnabled {
            regenerateShuffledIndices()
        }
        
        saveQueue()
        prebufferUpcomingTracks()
    }
    
    /// Remove a track from the queue
    func removeFromQueue(at index: Int) {
        guard index < queue.count else { return }
        
        let removedTrack = queue.remove(at: index)
        if let originalIndex = queueState.originalQueue.firstIndex(where: { $0.id == removedTrack.id }) {
            queueState.originalQueue.remove(at: originalIndex)
        }
        
        if isShuffleEnabled {
            regenerateShuffledIndices()
        }
        
        saveQueue()
    }
    
    /// Reorder tracks in the queue
    func moveTrack(from source: Int, to destination: Int) {
        guard source < queue.count, destination <= queue.count else { return }
        
        let track = queue.remove(at: source)
        queue.insert(track, at: destination > source ? destination - 1 : destination)
        
        // Update original queue as well
        queueState.originalQueue = queue
        
        if isShuffleEnabled {
            regenerateShuffledIndices()
        }
        
        saveQueue()
    }
    
    /// Clear the entire queue
    func clearQueue() {
        queue.removeAll()
        queueState = QueueState()
        currentTrack = nil
        nextTrack = nil
        queueHistory.removeAll()
        prebufferedFiles.removeAll()
        saveQueue()
    }
    
    // MARK: - Playback Control
    
    /// Play a specific track and set up the queue
    func play(track: Track, in tracks: [Track]) {
        clearQueue()
        queue = tracks
        queueState.originalQueue = tracks
        
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            queueState.currentIndex = index
            currentTrack = track
            
            if isShuffleEnabled {
                generateShuffleQueue(startingAt: index)
            }
            
            loadAndPlayCurrentTrack()
            preloadNextTrack()
            prebufferUpcomingTracks()
        }
        
        saveQueue()
    }
    
    /// Skip to the next track
    func skipToNext() {
        addToHistory(currentTrack)
        
        if let next = getNextTrack() {
            transitionToTrack(next)
        }
    }
    
    /// Skip to the previous track
    func skipToPrevious() {
        if let previous = queueHistory.popLast() {
            if let current = currentTrack {
                queue.insert(current, at: 0)
            }
            transitionToTrack(previous)
        }
    }
    
    // MARK: - Shuffle
    
    /// Toggle shuffle mode
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            generateShuffleQueue(startingAt: queueState.currentIndex)
        } else {
            // Restore original order
            queue = queueState.originalQueue
            if let current = currentTrack,
               let index = queue.firstIndex(where: { $0.id == current.id }) {
                queueState.currentIndex = index
            }
        }
        
        preloadNextTrack()
        prebufferUpcomingTracks()
    }
    
    // MARK: - Crossfade
    
    /// Set crossfade duration
    func setCrossfadeDuration(_ duration: TimeInterval) {
        crossfadeDuration = max(0, min(duration, 10)) // Limit to 0-10 seconds
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe when current track finishes
        audioEngine.$isPlaying
            .sink { [weak self] isPlaying in
                if !isPlaying, self?.currentTrack != nil {
                    self?.handleTrackCompletion()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadAndPlayCurrentTrack() {
        guard let track = currentTrack else { return }
        
        do {
            // Use prebuffered file if available
            if let bufferedFile = prebufferedFiles[track.url] {
                currentFile = bufferedFile
            } else {
                currentFile = try AVAudioFile(forReading: track.url)
            }
            
            guard let file = currentFile else { return }
            
            currentPlayer = AVAudioPlayerNode()
            audioEngine.engine.attach(currentPlayer!)
            audioEngine.engine.connect(currentPlayer!, to: audioEngine.engine.mainMixerNode, format: file.processingFormat)
            
            currentPlayer!.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.handleTrackCompletion()
                }
            }
            
            currentPlayer!.play()
            
        } catch {
            print("Error loading track: \(error)")
        }
    }
    
    private func preloadNextTrack() {
        preloadTask?.cancel()
        
        preloadTask = Task { @MainActor in
            guard let next = getNextTrack() else {
                nextTrack = nil
                return
            }
            
            nextTrack = next
            
            do {
                // Use prebuffered file if available
                if let bufferedFile = prebufferedFiles[next.url] {
                    nextFile = bufferedFile
                } else {
                    nextFile = try AVAudioFile(forReading: next.url)
                    prebufferedFiles[next.url] = nextFile
                }
                
                guard let file = nextFile else { return }
                
                nextPlayer = AVAudioPlayerNode()
                audioEngine.engine.attach(nextPlayer!)
                audioEngine.engine.connect(nextPlayer!, to: audioEngine.engine.mainMixerNode, format: file.processingFormat)
                
                // Schedule but don't play yet
                nextPlayer!.scheduleFile(file, at: nil)
                
            } catch {
                print("Error preloading next track: \(error)")
            }
        }
    }
    
    private func transitionToTrack(_ track: Track) {
        if crossfadeDuration > 0 {
            performCrossfade(to: track)
        } else {
            // Immediate transition
            stopCurrentPlayer()
            currentTrack = track
            loadAndPlayCurrentTrack()
            preloadNextTrack()
        }
        
        queueState.currentIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        saveQueue()
    }
    
    private func performCrossfade(to track: Track) {
        guard let nextPlayer = nextPlayer else {
            // Fallback to immediate transition
            transitionToTrack(track)
            return
        }
        
        // Start playing next track
        nextPlayer.play()
        nextPlayer.volume = 0
        
        // Animate volume changes
        let steps = 20
        let stepDuration = crossfadeDuration / Double(steps)
        var currentStep = 0
        
        crossfadeTimer?.invalidate()
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let progress = Float(currentStep) / Float(steps)
            
            self.currentPlayer?.volume = 1.0 - progress
            nextPlayer.volume = progress
            
            if currentStep >= steps {
                timer.invalidate()
                self.completeCrossfade(to: track)
            }
        }
    }
    
    private func completeCrossfade(to track: Track) {
        stopCurrentPlayer()
        
        // Swap players
        currentPlayer = nextPlayer
        currentFile = nextFile
        currentTrack = track
        nextPlayer = nil
        nextFile = nil
        
        preloadNextTrack()
        prebufferUpcomingTracks()
    }
    
    private func stopCurrentPlayer() {
        currentPlayer?.stop()
        if let player = currentPlayer {
            audioEngine.engine.detach(player)
        }
        currentPlayer = nil
    }
    
    private func handleTrackCompletion() {
        skipToNext()
    }
    
    private func getNextTrack() -> Track? {
        guard !queue.isEmpty else { return nil }
        
        let nextIndex = (queueState.currentIndex + 1) % queue.count
        return nextIndex < queue.count ? queue[nextIndex] : queue.first
    }
    
    private func addToHistory(_ track: Track?) {
        guard let track = track else { return }
        queueHistory.append(track)
        
        // Limit history size
        if queueHistory.count > 50 {
            queueHistory.removeFirst()
        }
    }
    
    // MARK: - Shuffle Implementation
    
    private func generateShuffleQueue(startingAt index: Int) {
        guard !queue.isEmpty else { return }
        
        var indices = Array(0..<queue.count)
        indices.remove(at: index)
        indices.shuffle()
        indices.insert(index, at: 0)
        
        queueState.shuffledIndices = indices
        
        // Reorder queue based on shuffled indices
        queue = indices.map { queueState.originalQueue[$0] }
        queueState.currentIndex = 0
    }
    
    private func regenerateShuffledIndices() {
        if let current = currentTrack,
           let currentIndex = queueState.originalQueue.firstIndex(where: { $0.id == current.id }) {
            generateShuffleQueue(startingAt: currentIndex)
        }
    }
    
    // MARK: - Prebuffering
    
    private func prebufferUpcomingTracks() {
        Task {
            let startIndex = queueState.currentIndex + 1
            let endIndex = min(startIndex + prebufferSize, queue.count)
            
            for i in startIndex..<endIndex {
                let track = queue[i]
                
                // Skip if already buffered
                if prebufferedFiles[track.url] != nil { continue }
                
                do {
                    let file = try AVAudioFile(forReading: track.url)
                    prebufferedFiles[track.url] = file
                } catch {
                    print("Error prebuffering track: \(error)")
                }
            }
            
            // Clean up old buffers
            cleanupPrebufferedFiles()
        }
    }
    
    private func cleanupPrebufferedFiles() {
        let currentAndUpcoming = Set(
            queue[queueState.currentIndex..<min(queueState.currentIndex + prebufferSize + 1, queue.count)]
                .map { $0.url }
        )
        
        prebufferedFiles = prebufferedFiles.filter { currentAndUpcoming.contains($0.key) }
    }
    
    // MARK: - Persistence
    
    private func saveQueue() {
        queuePersistence.save(
            queue: queue,
            currentTrackId: currentTrack?.id,
            history: queueHistory,
            isShuffleEnabled: isShuffleEnabled,
            crossfadeDuration: crossfadeDuration
        )
    }
    
    private func restoreQueue() {
        guard let restored = queuePersistence.restore() else { return }
        
        queue = restored.queue
        queueState.originalQueue = restored.queue
        queueHistory = restored.history
        isShuffleEnabled = restored.isShuffleEnabled
        crossfadeDuration = restored.crossfadeDuration
        
        if let currentId = restored.currentTrackId,
           let track = queue.first(where: { $0.id == currentId }),
           let index = queue.firstIndex(where: { $0.id == currentId }) {
            currentTrack = track
            queueState.currentIndex = index
            preloadNextTrack()
            prebufferUpcomingTracks()
        }
    }
}

// MARK: - Queue Persistence

private final class QueuePersistence {
    private let userDefaults = UserDefaults.standard
    private let queueKey = "AudioQueueManager.queue"
    private let historyKey = "AudioQueueManager.history"
    private let stateKey = "AudioQueueManager.state"
    
    struct PersistedState: Codable {
        let queue: [Track]
        let currentTrackId: String?
        let history: [Track]
        let isShuffleEnabled: Bool
        let crossfadeDuration: TimeInterval
    }
    
    func save(queue: [Track], currentTrackId: String?, history: [Track], isShuffleEnabled: Bool, crossfadeDuration: TimeInterval) {
        let state = PersistedState(
            queue: queue,
            currentTrackId: currentTrackId,
            history: history,
            isShuffleEnabled: isShuffleEnabled,
            crossfadeDuration: crossfadeDuration
        )
        
        if let data = try? JSONEncoder().encode(state) {
            userDefaults.set(data, forKey: stateKey)
        }
    }
    
    func restore() -> PersistedState? {
        guard let data = userDefaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data) else {
            return nil
        }
        return state
    }
}