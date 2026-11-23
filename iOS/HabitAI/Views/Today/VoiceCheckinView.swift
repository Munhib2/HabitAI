import SwiftUI
import Speech
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var permissionDenied = false

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    override init() {
        recognizer = SFSpeechRecognizer(locale: Locale.current)
        super.init()
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionDenied = status != .authorized
            }
        }
    }

    func startRecording() {
        transcript = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request, let recognizer = recognizer, recognizer.isAvailable else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = engine.inputNode
        request.shouldReportPartialResults = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        try? engine.start()
        isRecording = true
    }

    func stopRecording() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        isRecording = false
    }
}

struct VoiceCheckinView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var speech = SpeechRecognizer()
    @State private var isUploading = false
    @State private var result: VoiceTranscribeResponse?
    @State private var error: String?
    @State private var phase: Phase = .idle

    enum Phase { case idle, recording, processing, done }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Animated mic button
                ZStack {
                    if phase == .recording {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 150, height: 150)
                            .scaleEffect(speech.isRecording ? 1.3 : 1)
                            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: speech.isRecording)
                    }
                    Button {
                        if phase == .idle {
                            speech.startRecording()
                            phase = .recording
                        } else if phase == .recording {
                            speech.stopRecording()
                            phase = .processing
                            Task { await submit() }
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

                // Live transcript while recording
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
                    Text(error).foregroundColor(.red).font(.caption).padding(.horizontal)
                }

                if speech.permissionDenied {
                    Text("Microphone or speech permission denied. Enable in Settings.")
                        .foregroundColor(.orange).font(.caption).padding(.horizontal)
                }

                Spacer()

                if phase == .done {
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6366F1"))
                        .padding(.bottom, 30)
                } else if phase == .idle {
                    Text("Tap the mic and speak naturally")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.bottom, 30)
                }
            }
            .navigationTitle("Voice Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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

    func submit() async {
        let transcript = speech.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            error = "Nothing was recorded. Please try again."
            phase = .idle
            return
        }
        do {
            result = try await APIClient.shared.transcribeVoice(transcript: transcript)
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
