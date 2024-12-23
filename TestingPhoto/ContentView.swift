//
//  ContentView.swift
//  TestingPhoto
//
//  Created by esikmalazman on 19/12/2024.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var imageFolderPath: URL?
    @State private var isImporting = false
    @ObservedObject private var renderer = PhotogrammetryRenderer()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                        Button {
                            self.isImporting = true
                        } label: {
                            VStack(spacing: 16) {
                                Image(systemName: "folder.badge.plus.fill")
                                Text("Import Images")
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .font(.largeTitle)
                              .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                    
                    Button {
                        Task {
                            await startReconstruction()
                        }
                    } label: {
                        Label("Generate Model", systemImage: "square.and.arrow.down")
                     
                            .frame(maxWidth: .infinity)
                        
                    }
                    .padding()
                    .foregroundStyle(.white)
                    .background(Color.init(uiColor: .systemBlue))
                    .clipShape(.capsule)
                    .padding(.horizontal)
                
                }

             
                
                if renderer.isProgressing {
                    Color.black.opacity(0.5)
                        .overlay {
                                ProgressView {
                                    Text("Making 3D model: \(renderer.progress)")
                                }
                                .tint(.white)
                                .foregroundStyle(.white)
                        }
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $renderer.shouldPresentQuickLook) {
                if let modelURL = renderer.modelURL {
                    ARQuickLookView(modelFile: modelURL) {
                        renderer.shouldPresentQuickLook = false
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.folder]
            ) { result in
                switch result {
                case .success(let url):
                    print("Selected URL: \(url)")
                    read(from: url)
                    imageFolderPath = url
                case .failure(let failure):
                    print("Could not get selected URL : \(failure.localizedDescription)")
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    let isSupported = PhotogrammetrySession.isSupported
                
                    Label(
                        isSupported ? "Photogrammetry is supported" : "Photogrammetry is not supported"  ,
                        systemImage: isSupported ? "checkmark.circle" : "xmark.circle"
                    )
                    .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}


extension ContentView {
    func read(from url: URL) {
        let _ = url.startAccessingSecurityScopedResource()
    }
    
    private func startReconstruction() async {
        guard let imageFolderPath else { return }
        
        let modelFolderPath = imageFolderPath.appending(
            path: "Model/\(UUID().uuidString)_model.usdz"
        )
        
        renderer.render(
            inputFolder: imageFolderPath,
            outputFile: modelFolderPath,
            detail: .reduced
        )
    }
}

func createNewScanDirectory() -> URL? {
    let capturesFolder = URL.documentsDirectory.appendingPathComponent("Scans/", isDirectory: true)
    
    let formatter = ISO8601DateFormatter()
    let timestamp = formatter.string(from: Date())
    let newCaptureDirectory = capturesFolder.appendingPathComponent(timestamp,
                                                                    isDirectory: true)
    print("▶️ Start creating capture path: \(newCaptureDirectory)")
    let capturePath = newCaptureDirectory.path
    do {
        try FileManager.default.createDirectory(atPath: capturePath,
                                                withIntermediateDirectories: true)
    } catch {
        print("😨Failed to create capture path: \(capturePath) with error: \(String(describing: error))")
    }
    
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: capturePath,
                                                isDirectory: &isDirectory)
    guard exists, isDirectory.boolValue
    else { return nil }
    print("🎉 New capture path was created")
    return newCaptureDirectory
}
