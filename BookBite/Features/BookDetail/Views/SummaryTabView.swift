import SwiftUI

struct SummaryTabView: View {
    let summary: Summary
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("Summary Section", selection: $selectedTab) {
                Text("Overview").tag(0)
                Text("Apply").tag(1)
                Text("Full Summary").tag(2)
                Text("Analysis").tag(3)
                Text("References").tag(4)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.bottom, 16)
            
            TabView(selection: $selectedTab) {
                OverviewTab(summary: summary)
                    .tag(0)
                
                ApplicationTab(summary: summary)
                    .tag(1)
                
                ExtendedSummaryTab(summary: summary)
                    .tag(2)
                
                AnalysisTab(summary: summary)
                    .tag(3)
                
                ReferencesTab(summary: summary)
                    .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}

struct OverviewTab: View {
    let summary: Summary
    @State private var expandedIdeas: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Ideas")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(summary.keyIdeas.enumerated()), id: \.element.id) { index, idea in
                KeyIdeaRow(
                    idea: idea,
                    index: index + 1,
                    isExpanded: expandedIdeas.contains(idea.id)
                ) {
                    toggleExpanded(idea.id)
                }
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
    
    private func toggleExpanded(_ id: String) {
        if expandedIdeas.contains(id) {
            expandedIdeas.remove(id)
        } else {
            expandedIdeas.insert(id)
        }
    }
}

struct ApplicationTab: View {
    let summary: Summary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Apply at Work")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(summary.howToApply.enumerated()), id: \.element.id) { index, point in
                ApplicationPointRow(point: point, index: index + 1)
            }
            
            if !summary.whoShouldRead.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who Should Read This")
                        .font(.headline)
                    
                    Text(summary.whoShouldRead)
                        .font(.body)
                        .foregroundColor(.primary.opacity(0.9))
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 20)
            }
            
            Spacer()
        }
        .padding(.vertical)
    }
}

struct AnalysisTab: View {
    let summary: Summary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !summary.commonPitfalls.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Common Pitfalls")
                            .font(.headline)
                        
                        ForEach(Array(summary.commonPitfalls.enumerated()), id: \.offset) { index, pitfall in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text(pitfall)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if !summary.critiques.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Critical Perspectives")
                            .font(.headline)
                        
                        ForEach(Array(summary.critiques.enumerated()), id: \.offset) { index, critique in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.bubble")
                                    .foregroundColor(.purple)
                                    .font(.caption)
                                
                                Text(critique)
                                    .font(.body)
                            }
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                }
                
                if !summary.limitations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Limitations")
                            .font(.headline)
                        
                        Text(summary.limitations)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
}

struct ExtendedSummaryTab: View {
    let summary: Summary
    @State private var textSize: CGFloat = 16
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with controls
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Extended Summary")
                            .font(.headline)
                        
                        if let extendedSummary = summary.extendedSummary {
                            let wordCount = extendedSummary.split(separator: " ").count
                            Text("\(wordCount) words • \(Int(ceil(Double(wordCount) / 200))) min read")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Text size controls
                    HStack(spacing: 12) {
                        Button(action: { 
                            textSize = max(12, textSize - 2) 
                        }) {
                            Image(systemName: "textformat.size.smaller")
                                .foregroundColor(.primary)
                        }
                        .disabled(textSize <= 12)
                        
                        Button(action: { 
                            textSize = min(24, textSize + 2) 
                        }) {
                            Image(systemName: "textformat.size.larger")
                                .foregroundColor(.primary)
                        }
                        .disabled(textSize >= 24)
                    }
                    .font(.system(size: 14))
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.horizontal)
                
                // Extended summary content
                if let extendedSummary = summary.extendedSummary, !extendedSummary.isEmpty {
                    Text(extendedSummary)
                        .font(.system(size: textSize))
                        .lineSpacing(textSize * 0.3) // Dynamic line spacing based on text size
                        .padding(.horizontal)
                        .textSelection(.enabled) // Allow text selection for copying
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Extended Summary Not Available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This book doesn't have an extended summary yet. Extended summaries provide comprehensive, narrative-style overviews of the book's content.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 60)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }
}

struct ReferencesTab: View {
    let summary: Summary
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Citations & Sources")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(Array(summary.citations.enumerated()), id: \.element.source) { index, citation in
                    CitationRow(citation: citation, index: index + 1)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }
}