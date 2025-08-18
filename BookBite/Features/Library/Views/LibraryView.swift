import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var dependencies: DependencyContainer
    @StateObject private var viewModel: LibraryViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.categories.isEmpty {
                    LoadingView()
                } else if let error = viewModel.error {
                    CategoriesErrorView(error: error) {
                        Task {
                            await viewModel.loadCategories()
                        }
                    }
                } else {
                    CategoryGridView(categories: viewModel.categories)
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await viewModel.loadCategories()
            }
        }
    }
}

struct CategoryGridView: View {
    let categories: [BookCategory]
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(categories) { category in
                    NavigationLink(destination: CategoryBooksView(category: category)) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(CategoryCardButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct CategoriesErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Unable to Load Categories")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") {
                retry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}

struct CategoryCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                if newValue {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
    }
}