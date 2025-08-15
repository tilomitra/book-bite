import SwiftUI

struct ExportOptionsSheet: View {
    let book: Book
    let summary: Summary?
    
    @Environment(\.dismiss) var dismiss
    @State private var isExporting = false
    @State private var exportError: String?
    
    private let exportService = ExportService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isExporting {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Preparing export...")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    exportOptions
                }
            }
            .navigationTitle("Export Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
        }
    }
    
    var exportOptions: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                BookCoverView(coverURL: book.coverAssetName, size: .medium)
                
                Text(book.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("by \(book.formattedAuthors)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(16)
            
            VStack(spacing: 16) {
                exportOptionButton(
                    title: "Export as PDF",
                    subtitle: "One-page formatted summary",
                    icon: "doc.richtext",
                    color: .red
                ) {
                    exportPDF()
                }
                
                exportOptionButton(
                    title: "Export as Mind Map",
                    subtitle: "Visual hierarchy of key concepts",
                    icon: "brain.head.profile",
                    color: .purple
                ) {
                    exportMindMap()
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    func exportOptionButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func exportPDF() {
        guard let summary = summary else {
            exportError = "No summary available to export"
            return
        }
        
        isExporting = true
        
        Task {
            await MainActor.run {
                if let pdfData = exportService.exportAsPDF(book: book, summary: summary) {
                    sharePDF(data: pdfData)
                } else {
                    exportError = "Failed to generate PDF"
                }
                isExporting = false
            }
        }
    }
    
    func exportMindMap() {
        guard let summary = summary else {
            exportError = "No summary available to export"
            return
        }
        
        isExporting = true
        
        Task {
            await MainActor.run {
                if let image = exportService.exportAsMindMap(book: book, summary: summary) {
                    shareMindMap(image: image)
                } else {
                    exportError = "Failed to generate mind map"
                }
                isExporting = false
            }
        }
    }
    
    func sharePDF(data: Data) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(book.title).pdf")
        
        do {
            try data.write(to: tempURL)
            shareFile(url: tempURL)
        } catch {
            exportError = "Failed to save PDF: \(error.localizedDescription)"
        }
    }
    
    func shareMindMap(image: UIImage) {
        guard let imageData = image.pngData() else {
            exportError = "Failed to convert mind map to image"
            return
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(book.title)_mindmap.png")
        
        do {
            try imageData.write(to: tempURL)
            shareFile(url: tempURL)
        } catch {
            exportError = "Failed to save mind map: \(error.localizedDescription)"
        }
    }
    
    func shareFile(url: URL) {
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}