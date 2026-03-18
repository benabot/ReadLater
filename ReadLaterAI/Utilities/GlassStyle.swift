import SwiftUI

// MARK: - Liquid Glass Design System
// Approximation du design "Liquid Glass" d'Apple (WWDC 2025) pour macOS 14+.
//
// Principes :
// 1. Matériaux translucides (.ultraThinMaterial, .thinMaterial)
// 2. Bordures subtiles semi-transparentes
// 3. Coins très arrondis (12-16pt)
// 4. Profondeur via ombres douces et layers
// 5. Effets hover avec glow subtil
// 6. Pas de dividers durs — séparation par espace et opacité

// MARK: - Glass Card Modifier

/// Applique un style "glass card" à n'importe quelle vue.
/// Équivalent d'une carte translucide avec bordure lumineuse.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 12
    var isHighlighted: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHighlighted ? 0.4 : 0.15),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    /// Style carte glass translucide
    func glassCard(cornerRadius: CGFloat = 12, padding: CGFloat = 12, highlighted: Bool = false) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding, isHighlighted: highlighted))
    }
}

// MARK: - Glass Pill (pour les tags, badges, boutons)

struct GlassPill: ViewModifier {
    var color: Color = .accentColor

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func glassPill(color: Color = .accentColor) -> some View {
        modifier(GlassPill(color: color))
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(configuration.isPressed ? 0.25 : 0.15))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.3), lineWidth: 0.5)
                    )
            )
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Glass Divider (subtil, pas un trait dur)

struct GlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        .primary.opacity(0.08),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}
