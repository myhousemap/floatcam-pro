import SwiftUI
import AVFoundation

public struct CameraPreviewView: UIViewRepresentable {
    public let session: AVCaptureSession
    public let isMirrored: Bool

    public init(session: AVCaptureSession, isMirrored: Bool = false) {
        self.session = session
        self.isMirrored = isMirrored
    }

    public func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
        return view
    }

    public func updateUIView(_ uiView: PreviewUIView, context: Context) {
        if let connection = uiView.videoPreviewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }
}

public class PreviewUIView: UIView {
    public override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    public var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
