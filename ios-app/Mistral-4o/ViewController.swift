import UIKit
import AVFoundation
import SwiftUI

class ViewController: UIViewController {
    private var permissionGranted = true // Flag for permission
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sessionQueue")
    private var previewLayer = AVCaptureVideoPreviewLayer()
    var screenRect: CGRect! = nil // For view dimensions

    override func viewDidLoad() {
        super.viewDidLoad()
        checkPermission()

        sessionQueue.async { [unowned self] in
            guard self.permissionGranted else { return }
            self.setupCaptureSession()
            self.captureSession.startRunning()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Reset layers when view reappears
        self.previewLayer.frame = self.view.bounds
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        screenRect = UIScreen.main.bounds
        self.previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)

//        switch UIDevice.current.orientation {
//        case .portraitUpsideDown:
//            self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
//        case .landscapeLeft:
//            self.previewLayer.connection?.videoOrientation = .landscapeRight
//        case .landscapeRight:
//            self.previewLayer.connection?.videoOrientation = .landscapeLeft
//        case .portrait:
//            self.previewLayer.connection?.videoOrientation = .portrait
//        default:
//            break
//        }
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }

    func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: .video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }

    func setupCaptureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }

        guard captureSession.canAddInput(videoDeviceInput) else { return }
        captureSession.addInput(videoDeviceInput)

        screenRect = UIScreen.main.bounds

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        previewLayer.videoGravity = .resizeAspectFill // Fill screen

        DispatchQueue.main.async { [weak self] in
            self?.view.layer.addSublayer(self!.previewLayer)
        }
    }
}

struct HostedViewController: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return ViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}
