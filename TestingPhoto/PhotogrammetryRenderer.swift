//
//  Renderer.swift
//  TestingPhoto
//
//  Created by esikmalazman on 23/12/2024.
//

import RealityKit
import Foundation

public enum RenderErrors: Error {
    case photogrammetrySessionInitialization
    case invalidSample
}

/// Experiments in Photogrammetry: https://millsfield.sfomuseum.org/blog/2023/11/29/3d/
/// Adapted: https://github.com/sfomuseum/swift-photogrammetry-render
@available(macOS 12.0, iOS 17.0, *)
@MainActor
public class PhotogrammetryRenderer: ObservableObject {
    
    @Published var progress: String = ""
    @Published var isProgressing: Bool = false
    @Published var modelURL: URL?
    @Published var shouldPresentQuickLook = false
    
    public func render(
        inputFolder: URL,
        outputFile: URL,
        detail: PhotogrammetrySession.Request.Detail
    ) {
        let config = makeConfiguration()
        var optionalSession: PhotogrammetrySession? = nil
        
        do {
            setProgression(true)
            optionalSession = try PhotogrammetrySession(
                input: inputFolder,
                configuration: config)
        } catch {
            setProgression(false)
            print("Failed to create session, \(error)")
            return
        }
        
        guard let session = optionalSession else {
            print("Failed to initialize photogrammetry session")
            return
        }
        
        let waiter = Task {
            do {
                for try await output in session.outputs {
                    switch output {
                        
                    case .processingComplete:
                        print("Processing is complete")
                        self.modelURL = outputFile
                        self.shouldPresentQuickLook = true
                    case .requestError(let request, let error):
                        print("Request \(String(describing: request)) had an error: \(String(describing: error))")
                    case .requestProgress(_, let fractionComplete):
                        self.progress = "\(fractionComplete.formatted(.percent.precision(.fractionLength(1))))"
                        
                    case .requestProgressInfo(_, let info):
                        print("PROGRESS INFO : \(info)")
                    case .stitchingIncomplete:
                        print("Incomplete stitching")
                        
                    case .requestComplete(let request, let result):
                        setProgression(false)
                        print("Request \(String(describing: request)) had a result: \(String(describing: result))")
                        
                    case .inputComplete:
                        print("Data ingestion is complete, beginning processing...")
                    case .invalidSample(let id, let reason):
                        self.isProgressing = false
                        print("Invalid Sample, id=\(id) reason=\"\(reason)\"")
                    case .skippedSample(let id):
                        print("Sample id=\(id) was skipped by processing")
                    case .automaticDownsampling:
                        print("Automatic downsampling was applied")
                    case .processingCancelled:
                        self.isProgressing = false
                        print("Request of the session request was cancelled")
                    @unknown default:
                        self.isProgressing = false
                        print("Unhandled output message: \(String(describing: output))")
                    }
                }
            } catch {
                print("Failed to wait on task, \(error)")
            }
        }
        
        withExtendedLifetime((session, waiter)) {
            do {
                let request = PhotogrammetrySession.Request.modelFile(
                    url: outputFile,
                    detail: detail
                )
                
                try session.process(requests: [request])
                
            } catch {
                print("Failed to process session, \(error)")
            }
        }
    }
}


extension PhotogrammetryRenderer {
    func makeConfiguration() -> PhotogrammetrySession.Configuration {
        var config = PhotogrammetrySession.Configuration()
        config.featureSensitivity = .normal
        config.isObjectMaskingEnabled = true
        config.sampleOrdering = .unordered
        return config
    }
    
    func setProgression(_ state: Bool) {
        self.isProgressing = state
    }
}
