import SwiftUI
import PDFKit

class ExportService {
    
    func exportAsPDF(book: Book, summary: Summary?) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "BookBite",
            kCGPDFContextAuthor: book.formattedAuthors,
            kCGPDFContextTitle: book.title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold)
            ]
            let title = NSAttributedString(string: book.title, attributes: titleAttributes)
            title.draw(at: CGPoint(x: 50, y: yPosition))
            yPosition += 35
            
            if let subtitle = book.subtitle {
                let subtitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.gray
                ]
                let subtitleText = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
                subtitleText.draw(at: CGPoint(x: 50, y: yPosition))
                yPosition += 25
            }
            
            let authorAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium)
            ]
            let authors = NSAttributedString(string: "By \(book.formattedAuthors)", attributes: authorAttributes)
            authors.draw(at: CGPoint(x: 50, y: yPosition))
            yPosition += 30
            
            if let summary = summary {
                let hookAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.darkGray
                ]
                let hook = summary.oneSentenceHook
                let hookParagraph = NSMutableParagraphStyle()
                hookParagraph.lineBreakMode = .byWordWrapping
                
                let hookText = NSAttributedString(
                    string: hook,
                    attributes: hookAttributes.merging([.paragraphStyle: hookParagraph]) { $1 }
                )
                let hookRect = CGRect(x: 50, y: yPosition, width: 512, height: 60)
                hookText.draw(in: hookRect)
                yPosition += 70
                
                let sectionAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
                ]
                let keyIdeasTitle = NSAttributedString(string: "Key Ideas", attributes: sectionAttributes)
                keyIdeasTitle.draw(at: CGPoint(x: 50, y: yPosition))
                yPosition += 30
                
                let ideaAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                
                for (index, idea) in summary.keyIdeas.prefix(5).enumerated() {
                    let ideaText = "\(index + 1). \(idea.idea)"
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineBreakMode = .byWordWrapping
                    paragraph.lineSpacing = 2
                    
                    let attributedIdea = NSAttributedString(
                        string: ideaText,
                        attributes: ideaAttributes.merging([.paragraphStyle: paragraph]) { $1 }
                    )
                    
                    let ideaRect = CGRect(x: 50, y: yPosition, width: 512, height: 50)
                    attributedIdea.draw(in: ideaRect)
                    yPosition += 55
                    
                    if yPosition > 700 {
                        break
                    }
                }
                
                if yPosition < 650 {
                    let applyTitle = NSAttributedString(string: "How to Apply", attributes: sectionAttributes)
                    applyTitle.draw(at: CGPoint(x: 50, y: yPosition))
                    yPosition += 30
                    
                    for point in summary.howToApply.prefix(3) {
                        let pointText = "• \(point.action)"
                        let paragraph = NSMutableParagraphStyle()
                        paragraph.lineBreakMode = .byWordWrapping
                        
                        let attributedPoint = NSAttributedString(
                            string: pointText,
                            attributes: ideaAttributes.merging([.paragraphStyle: paragraph]) { $1 }
                        )
                        
                        let pointRect = CGRect(x: 50, y: yPosition, width: 512, height: 40)
                        attributedPoint.draw(in: pointRect)
                        yPosition += 45
                        
                        if yPosition > 700 {
                            break
                        }
                    }
                }
                
                let footerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.gray
                ]
                let footer = NSAttributedString(
                    string: "Generated by BookBite • \(summary.readTimeMinutes) minute read",
                    attributes: footerAttributes
                )
                footer.draw(at: CGPoint(x: 50, y: 742))
            }
        }
        
        return data
    }
    
    func exportAsMindMap(book: Book, summary: Summary?) -> UIImage? {
        let size = CGSize(width: 1024, height: 768)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            
            drawNode(
                context: context.cgContext,
                text: book.title,
                center: CGPoint(x: centerX, y: centerY),
                radius: 80,
                color: UIColor.systemBlue
            )
            
            guard let summary = summary else { return }
            
            let angleStep = (2 * CGFloat.pi) / CGFloat(summary.keyIdeas.count)
            let distance: CGFloat = 200
            
            for (index, idea) in summary.keyIdeas.prefix(8).enumerated() {
                let angle = CGFloat(index) * angleStep
                let x = centerX + cos(angle) * distance
                let y = centerY + sin(angle) * distance
                
                context.cgContext.setStrokeColor(UIColor.systemGray.cgColor)
                context.cgContext.setLineWidth(2)
                context.cgContext.move(to: CGPoint(x: centerX, y: centerY))
                context.cgContext.addLine(to: CGPoint(x: x, y: y))
                context.cgContext.strokePath()
                
                let truncatedIdea = String(idea.idea.prefix(30)) + (idea.idea.count > 30 ? "..." : "")
                drawNode(
                    context: context.cgContext,
                    text: truncatedIdea,
                    center: CGPoint(x: x, y: y),
                    radius: 60,
                    color: confidenceColor(for: idea.confidence)
                )
            }
        }
    }
    
    private func drawNode(context: CGContext, text: String, center: CGPoint, radius: CGFloat, color: UIColor) {
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedText.size()
        
        let textRect = CGRect(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        attributedText.draw(in: textRect)
    }
    
    private func confidenceColor(for confidence: Confidence) -> UIColor {
        switch confidence {
        case .high:
            return .systemGreen
        case .medium:
            return .systemOrange
        case .low:
            return .systemYellow
        }
    }
}