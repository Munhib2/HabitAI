import SwiftUI
import Speech
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permissionDenied = false
    @Published var statusError: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    override init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer(locale: Locale.current)
        super.init()
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status != .authorized {
                    self.permissionDenied = true
                }
            }
        }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.permissionDenied = true
                }
            }
        }
    }

    func startRecording() {
        statusError = nil
        transcript = ""

        if engine.isRunning {
            stopRecording()
        }

        guard let recognizer = recognizer, recognizer.isAvailable else {
            statusError = "Speech recognition unavailable on this device/simulator. Use text input below."
            return
        }

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                statusError = "No microphone input detected (Simulator). Type your check-in below."
                return
            }

            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if let result = result {
                    DispatchQueue.main.async {
                        self?.transcript = result.bestTranscription.formattedString
                    }
                }
                if let error = error {
                    DispatchQueue.main.async {
                        self?.statusError = error.localizedDescription
                    }
                }
            }

            engine.prepare()
            try engine.start()
            isRecording = true
        } catch {
            statusError = "Mic error: \(error.localizedDescription)"
            isRecording = false
        }
    }

    func stopRecording() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.finish()
        isRecording = false
    }
}

struct VoiceCheckinView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var speech = SpeechRecognizer()
    @State private var manualText = ""
    @State private var result: VoiceTranscribeResponse?
    @State private var error: String?
    @State private var phase: Phase = .idle

    enum Phase { case idle, recording, processing, done }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    if phase == .recording {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 150, height: 150)
                            .scaleEffect(speech.isRecording ? 1.3 : 1)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: speech.isRecording)
                    }
                    Button {
                        error = nil
                        if phase == .idle {
                            speech.startRecording()
                            if speech.isRecording {
                                phase = .recording
                            } else if let micErr = speech.statusError {
                                error = micErr
                            }
                        } else if phase == .recording {
                            speech.stopRecording()
                            phase = .processing
                            Task { await submit(text: speech.transcript) }
                        }
                    } label: {
                        Circle()
                            .fill(phase == .recording ? Color.red : Color(hex: "#6366F1"))
                            .frame(width: 110, height: 110)
                            .overlay(
                                Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                    }
                }

                VStack(spacing: 8) {
                    Text(phaseTitle).font(.title2).bold()
                    Text(phaseSubtitle)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if phase == .recording && !speech.transcript.isEmpty {
                    Text(speech.transcript)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                if phase == .processing {
                    ProgressView("Analyzing your habits...")
                }

                if let result = result, phase == .done {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I heard:")
                            .font(.caption).foregroundColor(.secondary)
                        Text(result.transcript)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        Text("Logged \(result.parsed.completions.filter { $0.completed }.count) habit(s) ✓")
                            .font(.subheadline).foregroundColor(.green)
                    }
                    .padding(.horizontal)
                }

                if let error = error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                if speech.permissionDenied {
                    Text("Microphone or speech permission denied. Enable in iPhone Settings.")
                        .foregroundColor(.orange).font(.caption).padding(.horizontal)
                }

                // Quick Text Input (Great for Simulator or noisy places)
                if phase == .idle {
                    HStack {
                        TextField("Or type: I completed running today...", text: $manualText)
                            .textFieldStyle(.roundedBorder)
                        Button("Send") {
                            let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            phase = .processing
                            Task { await submit(text: text) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6366F1"))
                        .disabled(manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                if phase == .done {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6366F1"))
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Voice Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        speech.stopRecording()
                        dismiss()
                    }
                }
            }
            .onAppear { speech.requestPermission() }
        }
    }

    var phaseTitle: String {
        switch phase {
        case .idle: return "Tap Mic to Start"
        case .recording: return "Listening..."
        case .processing: return "Processing..."
        case .done: return "All Done!"
        }
    }

    var phaseSubtitle: String {
        switch phase {
        case .idle: return "Say what you did today:\n\"I ran for 30 minutes and read for an hour\""
        case .recording: return "Tap the button again when you're finished"
        case .processing: return "AI is logging your check-ins"
        case .done: return "Your habits have been updated"
        }
    }

    func submit(text: String) async {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            error = "Nothing was recorded. Please try again."
            phase = .idle
            return
        }
        do {
            result = try await APIClient.shared.transcribeVoice(transcript: cleaned)
            phase = .done
        } catch APIError.premiumRequired {
            error = "Voice check-in is a Premium feature."
            phase = .idle
        } catch {
            self.error = error.localizedDescription
            phase = .idle
        }
    }
}
