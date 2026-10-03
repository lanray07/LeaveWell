import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct CapturedMedia {
    let data: Data?
    let url: URL?
    let name: String
    let capturedAt: Date
    let origin: CaptureOrigin
}

/// Apple's camera supplies capture, zoom, flash, review and retake controls.
/// The first saved representation is retained; later edits never replace it.
struct SystemCamera: UIViewControllerRepresentable {
    let video: Bool
    let completion: (Result<CapturedMedia, Error>?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera; controller.delegate = context.coordinator
        controller.mediaTypes = [video ? UTType.movie.identifier : UTType.image.identifier]
        controller.cameraCaptureMode = video ? .video : .photo
        controller.videoQuality = .typeHigh; controller.allowsEditing = false
        return controller
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (Result<CapturedMedia, Error>?) -> Void
        init(completion: @escaping (Result<CapturedMedia, Error>?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let now = Date()
            if let url = info[.mediaURL] as? URL {
                completion(.success(CapturedMedia(data: nil, url: url, name: url.lastPathComponent, capturedAt: now, origin: .camera)))
            } else if let url = info[.imageURL] as? URL {
                completion(.success(CapturedMedia(data: nil, url: url, name: url.lastPathComponent, capturedAt: now, origin: .camera)))
            } else if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 1) {
                completion(.success(CapturedMedia(data: data, url: nil, name: "capture.jpg", capturedAt: now, origin: .camera)))
            } else { completion(.failure(VaultError.emptyFile)) }
        }
    }
}

struct DocumentScanner: UIViewControllerRepresentable {
    let completion: (Result<[Data], Error>?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: (Result<[Data], Error>?) -> Void
        init(completion: @escaping (Result<[Data], Error>?) -> Void) { self.completion = completion }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { completion(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { completion(.failure(error)) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let pages = (0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).jpegData(compressionQuality: 1) }
            completion(.success(pages))
        }
    }
}
