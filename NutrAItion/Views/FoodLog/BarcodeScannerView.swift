//
//  BarcodeScannerView.swift
//  NutrAItion
//

import SwiftUI
import VisionKit

#if targetEnvironment(simulator)
// Simulator: no camera — show text field to enter UPC manually.
struct BarcodeScannerView: View {
    var onBarcodeDetected: (String) -> Void
    var onCancel: () -> Void

    @State private var upcInput = ""

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            Spacer()
            Text("Barcode scanner unavailable in Simulator")
                .font(.headline)
            TextField("Enter UPC / barcode", text: $upcInput)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.horizontal, 40)
            Button("Look up") {
                let trimmed = upcInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    onBarcodeDetected(trimmed)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
}
#else
// Real device: DataScannerViewController with overlay and cancel.
struct BarcodeScannerView: View {
    var onBarcodeDetected: (String) -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DataScannerRepresentable(onBarcodeDetected: onBarcodeDetected)
                .ignoresSafeArea()
            ScanningOverlay()
                .allowsHitTesting(false)
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            .padding()
        }
    }
}

// MARK: - DataScanner UIViewControllerRepresentable

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    var onBarcodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcodeDetected)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onBarcode: (String) -> Void

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let item = addedItems.first else { return }
            if case .barcode(let code) = item {
                onBarcode(code.payloadStringValue ?? "")
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            // Optional: surface error to user
        }
    }
}

// MARK: - Overlay: dark corners, bright center rectangle

private struct ScanningOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rectW = min(w * 0.75, 280)
            let rectH = min(h * 0.25, 120)
            let centerRect = CGRect(
                x: (w - rectW) / 2,
                y: (h - rectH) / 2,
                width: rectW,
                height: rectH
            )
            ZStack {
                Color.black.opacity(0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)
                            .frame(width: rectW, height: rectH)
                            .position(x: centerRect.midX, y: centerRect.midY)
                            .blendMode(.destinationOut)
                    )
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.8), lineWidth: 2)
                    .frame(width: rectW, height: rectH)
                    .position(x: centerRect.midX, y: centerRect.midY)
            }
        }
    }
}
#endif

#Preview {
    BarcodeScannerView(
        onBarcodeDetected: { _ in },
        onCancel: { }
    )
}
