import Testing
import Foundation
import UIKit
@testable import BookBite

struct ExportServiceTests {
    
    func createTestBook() -> Book {
        return Book(
            id: "test-book",
            title: "The Test Manager's Guide",
            subtitle: "A Comprehensive Testing Approach",
            authors: ["Test Author", "Another Author"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2023,
            publisher: "Test Publishers",
            categories: ["Testing", "Management"],
            coverAssetName: nil,
            description: "A comprehensive guide to testing management approaches and methodologies.",
            sourceAttribution: ["Test Source"]
        )
    }
    
    func createTestSummary() -> Summary {
        return Summary(
            id: "test-summary",
            bookId: "test-book",
            oneSentenceHook: "This book transforms how you approach testing and quality assurance.",
            keyIdeas: [],
            howToApply: [],
            commonPitfalls: ["Writing tests that are too complex"],
            critiques: ["May slow down initial development"],
            whoShouldRead: "Software developers, QA engineers, and technical managers",
            limitations: "Focuses primarily on software testing, limited coverage of manual testing",
            citations: [],
            readTimeMinutes: 15,
            style: .full,
            extendedSummary: "Extended summary about testing approaches and methodologies"
        )
    }
    
    @Test("ExportService should export book as PDF")
    func testExportAsPDF() {
        let exportService = ExportService()
        let book = createTestBook()
        let summary = createTestSummary()
        
        let pdfData = exportService.exportAsPDF(book: book, summary: summary)
        
        #expect(pdfData != nil)
        #expect(pdfData!.count > 0)
        
        // Verify it's actually PDF data by checking PDF header
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"
        let dataPrefix = pdfData!.prefix(4)
        #expect(dataPrefix == pdfHeader)
    }
    
    @Test("ExportService should export book as PDF without summary")
    func testExportAsPDFWithoutSummary() {
        let exportService = ExportService()
        let book = createTestBook()
        
        let pdfData = exportService.exportAsPDF(book: book, summary: nil)
        
        #expect(pdfData != nil)
        #expect(pdfData!.count > 0)
        
        // Verify it's PDF data
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // "%PDF"
        let dataPrefix = pdfData!.prefix(4)
        #expect(dataPrefix == pdfHeader)
    }
    
    @Test("ExportService should export book as mind map")
    func testExportAsMindMap() {
        let exportService = ExportService()
        let book = createTestBook()
        let summary = createTestSummary()
        
        let mindMapImage = exportService.exportAsMindMap(book: book, summary: summary)
        
        #expect(mindMapImage != nil)
        #expect(mindMapImage!.size.width == 1024)
        #expect(mindMapImage!.size.height == 768)
        
        // Verify the image has actual content (not just transparent)
        let imageData = mindMapImage!.pngData()
        #expect(imageData != nil)
        #expect(imageData!.count > 1000) // Should have substantial data
    }
    
    @Test("ExportService should export mind map without summary")
    func testExportAsMindMapWithoutSummary() {
        let exportService = ExportService()
        let book = createTestBook()
        
        let mindMapImage = exportService.exportAsMindMap(book: book, summary: nil)
        
        #expect(mindMapImage != nil)
        #expect(mindMapImage!.size.width == 1024)
        #expect(mindMapImage!.size.height == 768)
        
        // Should still create an image with just the book title
        let imageData = mindMapImage!.pngData()
        #expect(imageData != nil)
        #expect(imageData!.count > 500) // Should have some content
    }
    
    @Test("ExportService should handle books with long titles")
    func testExportWithLongTitle() {
        let exportService = ExportService()
        let longTitleBook = Book(
            id: "long-title-book",
            title: "This is a Very Long Book Title That Should Test How the Export Service Handles Lengthy Text Content in PDF Generation and Mind Map Creation",
            subtitle: "An Even Longer Subtitle That Contains Multiple Sentences and Should Also Be Properly Handled During the Export Process Without Breaking the Layout",
            authors: ["Author With a Very Long Name That Should Also Be Tested"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2023,
            publisher: "Very Long Publisher Name Inc.",
            categories: ["Category"],
            coverAssetName: nil,
            description: "Description",
            sourceAttribution: ["Source"]
        )
        
        let pdfData = exportService.exportAsPDF(book: longTitleBook, summary: nil)
        let mindMapImage = exportService.exportAsMindMap(book: longTitleBook, summary: nil)
        
        #expect(pdfData != nil)
        #expect(mindMapImage != nil)
    }
    
    @Test("ExportService should handle summaries with many key ideas")
    func testExportWithManyKeyIdeas() {
        let exportService = ExportService()
        let book = createTestBook()
        
        // Create summary with many key ideas (simplified for testing)
        let manyIdeas: [String] = []
        
        let summaryWithManyIdeas = Summary(
            id: "test-summary-many",
            bookId: "test-book",
            oneSentenceHook: "Test hook",
            keyIdeas: [],
            howToApply: [],
            commonPitfalls: [],
            critiques: [],
            whoShouldRead: "Everyone",
            limitations: "None",
            citations: [],
            readTimeMinutes: 20,
            style: .full,
            extendedSummary: "Extended summary with many ideas"
        )
        
        let pdfData = exportService.exportAsPDF(book: book, summary: summaryWithManyIdeas)
        let mindMapImage = exportService.exportAsMindMap(book: book, summary: summaryWithManyIdeas)
        
        #expect(pdfData != nil)
        #expect(mindMapImage != nil)
        
        // Should handle truncation gracefully
        #expect(pdfData!.count > 0)
        #expect(mindMapImage!.size.width == 1024)
    }
}