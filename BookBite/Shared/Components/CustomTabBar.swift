import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [TabItem]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                CustomTabBarButton(
                    tab: tabs[index],
                    isSelected: selectedTab == index,
                    action: {
                        withAnimation(DesignSystem.Animations.bouncy) {
                            selectedTab = index
                        }
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(
                    color: DesignSystem.Shadow.large.color,
                    radius: DesignSystem.Shadow.large.radius,
                    x: DesignSystem.Shadow.large.x,
                    y: DesignSystem.Shadow.large.y
                )
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
}

struct CustomTabBarButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    // Background circle for selected state - monochrome
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 44, height: 44)
                        .scaleEffect(isSelected ? 1.0 : 0.1)
                        .opacity(isSelected ? 1.0 : 0.0)
                        .animation(DesignSystem.Animations.bouncy, value: isSelected)

                    // Icon - monochrome
                    Image(systemName: isSelected ? tab.iconFilled : tab.icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isSelected ? Color(UIColor.systemBackground) : DesignSystem.Colors.textSecondary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(DesignSystem.Animations.spring, value: isSelected)
                }

                // Label - monochrome
                Text(tab.title)
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? .primary : DesignSystem.Colors.textSecondary)
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(DesignSystem.Animations.smooth, value: isSelected)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(DesignSystem.Animations.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            withAnimation(DesignSystem.Animations.quick) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignSystem.Animations.quick) {
                    isPressed = false
                }
            }

            action()
        }
    }
}

struct TabItem {
    let title: String
    let icon: String
    let iconFilled: String
}

// MARK: - Tab Items Configuration
extension TabItem {
    static let nytBest = TabItem(
        title: "Featured",
        icon: "star",
        iconFilled: "star.fill"
    )

    static let swipe = TabItem(
        title: "Discover",
        icon: "rectangle.stack",
        iconFilled: "rectangle.stack.fill"
    )

    static let search = TabItem(
        title: "Search",
        icon: "magnifyingglass",
        iconFilled: "magnifyingglass"
    )

    static let settings = TabItem(
        title: "Settings",
        icon: "gearshape",
        iconFilled: "gearshape.fill"
    )
}

// MARK: - Custom Tab View
struct CustomTabView: View {
    @State private var selectedTab = 0
    
    let tabs = [TabItem.nytBest, TabItem.swipe, TabItem.search, TabItem.settings]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack {
                        FeaturedBooksView()
                    }
                case 1:
                    SwipeView()
                case 2:
                    NavigationStack {
                        SearchView()
                    }
                case 3:
                    NavigationStack {
                        SettingsView()
                    }
                default:
                    NavigationStack {
                        FeaturedBooksView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab, tabs: tabs)
        }
        .background(DesignSystem.Colors.background)
    }
}