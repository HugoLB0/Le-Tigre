import SwiftUI
import SiriWaveView

struct ContentView: View {
    @State private var vm = ViewModel()
    @State private var isSymbolAnimating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Le Tigre")
                .font(.title)

            //Spacer()

            // Camera view
            CameraView()
            
            Spacer()
            
            // Chatbot interface
            SiriWaveView()
                .power(power: vm.audioPower)
                .opacity(vm.siriWaveFormOpacity)
                .frame(height: 256)
                .overlay { overlayView }

            //Spacer()
            //Spacer()

            switch vm.state {
            case .recordingSpeech:
                cancelButton

            case .processingSpeech, .playingSpeech:
                cancelButton

            default:
                EmptyView()
            }

            if case let .error(error) = vm.state {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(2)
            }
        }
        .padding()
    }

    @ViewBuilder
    var overlayView: some View {
        switch vm.state {
        case .idle, .error:
            startCaptureButton
        case .processingSpeech:
            Image(systemName: "cat.fill")
                .symbolEffect(.bounce.up.byLayer, options: .repeating, value: isSymbolAnimating)
                .font(.system(size: 100))
                .onAppear { isSymbolAnimating = true }
                .onDisappear { isSymbolAnimating = false }
        default:
            EmptyView()
        }
    }

    var startCaptureButton: some View {
            Button {
                vm.startCaptureAudio()
            } label: {
                Image(systemName: "cat.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 128))
                    .foregroundColor(.black)
            }.buttonStyle(.borderless)
        }


    var cancelButton: some View {
        Button(role: .destructive){
                vm.stopCaptureAudio()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.red)
                    .font(.system(size: 44))
            }.buttonStyle(.borderless)
        }

//    var cancelButton: some View {
//        Button(role: .destructive) {
//            vm.cancelProcessingTask()
//        } label: {
//            Image(systemName: "stop.circle.fill")
//                .symbolRenderingMode(.monochrome)
//                .foregroundStyle(.red)
//                .font(.system(size: 44))
//        }.buttonStyle(.borderless)
//    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
