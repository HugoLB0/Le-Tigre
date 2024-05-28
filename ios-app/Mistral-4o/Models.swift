import Foundation


enum VoiceChatState {
    case idle
    case recordingSpeech
    case processingSpeech
    case playingSpeech
    case recordingCamera
    case error(Error)
}
