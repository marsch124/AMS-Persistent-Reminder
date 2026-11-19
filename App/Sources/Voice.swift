import Foundation
import AVFoundation
import Speech

/// 0.5 (voice): listens while the round + is held, and gives back the words heard.
@MainActor
final class SpeechListener: ObservableObject {
    enum Notice: Equatable { case didntCatch, needsPermission }

    @Published var listening = false
    @Published var heard = ""
    @Published var notice: Notice?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var wanted = false
    private var running = false
    private var finalReceived = false

    func start() {
        guard !listening else { return }
        wanted = true; listening = true; heard = ""; notice = nil; finalReceived = false
        Task { await begin() }
    }

    /// Lets go: stops listening and returns what was heard (empty when nothing).
    func finish() async -> String {
        wanted = false
        guard running else { listening = false; return "" }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        // Give the recogniser a moment to settle its last words.
        for _ in 0..<8 where !finalReceived { try? await Task.sleep(nanoseconds: 100_000_000) }
        task?.cancel()
        task = nil; request = nil; running = false; listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return heard.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func begin() async {
        let speechOK = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        let micOK = await AVAudioApplication.requestRecordPermission()
        guard speechOK, micOK else {
            wanted = false; listening = false; notice = .needsPermission
            return
        }
        // Let go while the permission questions were showing: nothing to do.
        guard wanted else { listening = false; return }

        var recognizer = SFSpeechRecognizer(locale: Locale.current)
        if recognizer == nil || recognizer?.isAvailable == false { recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) }
        guard let recognizer, recognizer.isAvailable else {
            wanted = false; listening = false; notice = .didntCatch
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
            engine.prepare()
            try engine.start()
            running = true
        } catch {
            wanted = false; listening = false; notice = .didntCatch
            return
        }

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.heard = result.bestTranscription.formattedString
                    if result.isFinal { self.finalReceived = true }
                }
                if error != nil { self.finalReceived = true }
            }
        }
        // Let go before the engine was ready.
        if !wanted { _ = await finish() }
    }
}
