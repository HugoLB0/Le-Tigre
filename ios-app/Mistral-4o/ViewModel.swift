import AVFoundation
import Foundation
import Observation
import XCAOpenAIClient
import ElevenlabsSwift
import CoreImage
import UIKit

@Observable
class ViewModel: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    let client = OpenAIClient(apiKey: "OPENAI-API-KEY")
    var audioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!
    #if !os(macOS)
    var recordingSession = AVAudioSession.sharedInstance()
    #endif
    var animationTimer: Timer?
    var recordingTimer: Timer?
    var audioPower = 0.0
    var prevAudioPower: Double?
    var processingSpeechTask: Task<Void, Error>?

    let elevenApi = ElevenlabsSwift(elevenLabsAPI: "ELEVEN-LABS-API")
        
    var captureURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("recording.m4a")
    }

    var state = VoiceChatState.idle {
        didSet { print("State changed: \(state)") }
    }

    var isIdle: Bool {
        if case .idle = state {
            return true
        }
        return false
    }

    func stopCaptureAudio() {
        switch state {
        case .recordingSpeech:
            finishCaptureAudio()
        default:
            startCaptureAudio()
        }
    }

    var siriWaveFormOpacity: CGFloat {
        switch state {
        case .recordingSpeech, .playingSpeech: return 1
        default: return 0
        }
    }

    override init() {
        super.init()
        #if !os(macOS)
        do {
            #if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #else
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            #endif
            try recordingSession.setActive(true)

            AVAudioApplication.requestRecordPermission { [unowned self] allowed in
                if !allowed {
                    self.state = .error("Recording not allowed by the user")
                }
            }
        } catch {
            state = .error(error)
        }
        #endif

        setupCaptureSession()  // Ensure the capture session is set up during initialization
    }

    var lowPowerCounter = 0
    let lowPowerThreshold = 0.5
    let lowPowerDuration = 5 // Number of consecutive checks required to stop recording

    func startCaptureAudio() {
        resetValues()
        state = .recordingSpeech
        do {
            audioRecorder = try AVAudioRecorder(url: captureURL,
                                                settings: [
                                                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                                    AVSampleRateKey: 12000,
                                                    AVNumberOfChannelsKey: 1,
                                                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                                                ])
            audioRecorder.isMeteringEnabled = true
            audioRecorder.delegate = self
            audioRecorder.record()

            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                self.audioPower = power
            })

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                if self.prevAudioPower == nil {
                    self.prevAudioPower = power
                    return
                }
                if power < lowPowerThreshold {
                    self.lowPowerCounter += 1
                    if self.lowPowerCounter >= self.lowPowerDuration {
                        self.finishCaptureAudio()
                        return
                    }
                } else {
                    self.lowPowerCounter = 0
                }
                self.prevAudioPower = power
            })

        } catch {
            resetValues()
            state = .error(error)
        }
    }

    func resetValues() {
        audioPower = 0
        prevAudioPower = nil
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
        lowPowerCounter = 0 // Reset the counter
    }

    func sendPromptToServer(text: String, completion: @escaping (String?) -> Void) {
        let serverURL = "SERVER_URL_WITH_THE_BACKEND" // Use local IP for physical device

        guard let url = URL(string: "\(serverURL)/prompt?prompt=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            print("Invalid URL")
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = Data()
        request.httpBody = body

        // Log the request details
        print("Sending request to server with URL: \(url)")
        print("HTTP Method: \(request.httpMethod ?? "N/A")")
        print("HTTP Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Request Body Size: \(body.count) bytes")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending data to server: \(error.localizedDescription)")
                if let underlyingError = error as NSError? {
                    print("Underlying error: \(underlyingError.userInfo)")
                }
                completion(nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from server")
                completion(nil)
                return
            }

            if httpResponse.statusCode == 200 {
                print("Successfully sent data to server")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response from server: \(responseString)")
                    completion(responseString)
                } else {
                    completion(nil)
                }
            } else {
                print("Server returned status code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response from server: \(responseString)")
                }
                completion(nil)
            }
        }
        task.resume()
    }

    private var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput = AVCapturePhotoOutput()
    private var currentFrame: UIImage?

    func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        guard captureSession.canAddInput(videoDeviceInput) else { return }

        captureSession.addInput(videoDeviceInput)
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.addOutput(photoOutput)
        
        print("Starting capture session")
        captureSession.startRunning()  // Start the session
        print("Capture session started")
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        if !captureSession.isRunning {
            print("Capture session is not running, starting it now")
            captureSession.startRunning()
        }

        let settings = AVCapturePhotoSettings()
        print("Capturing photo...")
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func sendCapturedImageToServer(image: UIImage) {
        let serverURL = "SERVER_URL_WITH_THE_BACKEND" // Use local IP for physical device

        guard let url = URL(string: "\(serverURL)/image") else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        if let imageData = image.jpegData(compressionQuality: 1.0) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"image\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        } else {
            print("Failed to convert image to JPEG data")
            return
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        // Log the request details
        print("Sending image to server with URL: \(url)")
        print("HTTP Method: \(request.httpMethod ?? "N/A")")
        print("HTTP Headers: \(request.allHTTPHeaderFields ?? [:])")
        print("Request Body Size: \(body.count) bytes")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending image to server: \(error.localizedDescription)")
                if let underlyingError = error as NSError? {
                    print("Underlying error: \(underlyingError.userInfo)")
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from server")
                return
            }

            if httpResponse.statusCode == 200 {
                print("Successfully sent image to server")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response from server: \(responseString)")
                }
            } else {
                print("Server returned status code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response from server: \(responseString)")
                }
            }
        }
        task.resume()
    }

    func finishCaptureAudio() {
        resetValues()
        do {
            let data = try Data(contentsOf: captureURL)
            processingSpeechTask = processSpeechTask(audioData: data)
        } catch {
            state = .error(error)
            resetValues()
        }
    }
    
    func fetchPromptFromServer() async throws -> String {
        print("inside fetch_prompt")
        guard let url = URL(string: "SERVER_URL_WITH_THE_BACKEND") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        print(data)
        
        guard let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
              let jsonDict = jsonResponse as? [String: Any],
              let promptText = jsonDict["llm_response"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON response"])
        }
        print(promptText)
        return promptText
    }
    
    

    func processSpeechTask(audioData: Data) -> Task<Void, Error> {
        Task { [unowned self] in
            async {
                do {
                    self.state = .processingSpeech
                    let prompt = try await client.generateAudioTransciptions(audioData: audioData)

                    print("Transcribed Question: \(prompt)")
                    sendPromptToServer(text: prompt) { [weak self] response in
                        guard let self = self else { return }
                        // Ensure capture session is running before capturing photo
                        self.capturePhoto { image in
                            guard let image = image else {
                                print("Failed to capture image")
                                return
                            }
                            self.sendCapturedImageToServer(image: image)
                            self.resetCaptureSession()  // Ensure capture session is reset
                        }
                    }
                    
                    
                    do {
                        sleep(4)
                    }
                    
                    // let responseText = try await client.promptChatGPT(prompt: prompt)
                    print("fetching response")
                    let responseText = try await fetchPromptFromServer()
                    
                    let fileURL = try await textToSpeech(text: responseText)
                    //let fileURL = try await elevenApi.textToSpeech(
                     //   voice_id: "HcntxZ9B1itCz428Q359", text: responseText, model: "eleven_turbo_v2")
                    try await self.playAudio(fileURL: fileURL)
                } catch {
                    state = .error(error)
                    resetValues()
                }
            }
        }
    }
    
    func textToSpeech(text: String) async throws -> URL {
        print("elevenlabs:")
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/MODEL_ID") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("XI-API-KEY", forHTTPHeaderField: "xi-api-key")
        
        
        let parameters: [String: Any] = [
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.3,
                "style": 0.4,
                "use_speaker_boost": true
            ],
            "model_id": "eleven_turbo_v2",
            "text": text
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let fileName = UUID().uuidString + ".mp3"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        
        return fileURL
    }

    func playAudio(fileURL: URL) async throws {
        self.state = .playingSpeech
        audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
        audioPlayer.isMeteringEnabled = true
        audioPlayer.delegate = self
        audioPlayer.play()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
            guard self.audioPlayer != nil else { return }
            self.audioPlayer.updateMeters()
            let power = min(1, max(0, 1 - abs(Double(self.audioPlayer.averagePower(forChannel: 0)) / 160) ))
            self.audioPower = power
        })
    }

    func resetCaptureSession() {
        print("Resetting capture session")
        captureSession.stopRunning()
        setupCaptureSession()
    }

    func cancelRecording() {
        resetValues()
        state = .idle
    }

    func cancelProcessingTask() {
        processingSpeechTask?.cancel()
        processingSpeechTask = nil
        resetValues()
        state = .idle
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            resetValues()
            state = .idle
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resetValues()
        state = .idle
    }

    // Implement the photo output delegate method directly in the ViewModel class
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("Failed to get image data representation")
            return
        }

        let image = UIImage(data: imageData)
        sendCapturedImageToServer(image: image!)
        resetCaptureSession()  // Ensure capture session is reset
    }
}
