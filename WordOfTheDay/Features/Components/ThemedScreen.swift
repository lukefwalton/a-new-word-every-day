import SwiftUI
import UIKit
import LFWDesignSystem

/// Shared chrome for in-app screens: themed gradient backdrop + navigation styling.
struct ThemedScreen<Content: View>: View {
    let theme: LFWThemeConfig
    var animateBackground: Bool = false
    @ViewBuilder var content: () -> Content

    private var palette: LFWPaletteColors { theme.colors }

    var body: some View {
        ZStack {
            LFWThemedBackground(config: theme, animated: animateBackground)
            content()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(theme.palette.isDark ? .dark : .light, for: .navigationBar)
    }
}

/// Theme-aware primary/secondary pills (Today know/skip controls).
struct ThemedCTAButtonStyle: ButtonStyle {
    let palette: LFWPaletteColors
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(filled ? palette.backgroundTop : palette.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous)
                    .fill(filled ? palette.primaryText : palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: LFWRadius.card, style: .continuous)
                    .strokeBorder(
                        filled ? Color.clear : palette.primaryText.opacity(0.35),
                        lineWidth: 1
                    )
            )
            .shadow(color: filled ? .black.opacity(0.12) : .clear, radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ThemedCTAButtonStyle {
    static func themedCTA(palette: LFWPaletteColors, filled: Bool = true) -> ThemedCTAButtonStyle {
        ThemedCTAButtonStyle(palette: palette, filled: filled)
    }
}

/// Applies themed list/form styling over the gradient background.
struct ThemedListChrome: ViewModifier {
    let palette: LFWPaletteColors

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listRowBackground(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .fill(palette.backgroundBottom.opacity(0.72))
                    .padding(.vertical, 2)
            )
            .listRowSeparatorTint(palette.primaryText.opacity(0.12))
    }
}

struct ThemedFormChrome: ViewModifier {
    let palette: LFWPaletteColors

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .listRowBackground(
                RoundedRectangle(cornerRadius: LFWRadius.surface, style: .continuous)
                    .fill(palette.backgroundBottom.opacity(0.72))
            )
            .listRowSeparatorTint(palette.primaryText.opacity(0.10))
    }
}

enum TabBarAppearance {
    /// Match the tab bar to the active palette.
    static func apply(theme: LFWThemeConfig) {
        let colors = theme.colors
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(colors.backgroundTop.opacity(0.92))
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(colors.secondaryText)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(colors.secondaryText)
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(colors.accent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(colors.accent)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
