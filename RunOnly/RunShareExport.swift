import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum RunShareExportError: LocalizedError {
    case renderFailed
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return L10n.tr("공유 이미지를 렌더링하지 못했습니다.")
        case .photoSaveFailed:
            return L10n.tr("사진 앱에 저장하지 못했습니다.")
        }
    }
}

enum PhotoLibraryPNGWriter {
    static func save(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: RunShareExportError.photoSaveFailed)
                }
            })
        }
    }
}

