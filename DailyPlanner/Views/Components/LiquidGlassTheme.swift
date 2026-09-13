import SwiftUI

// MARK: - Environment Keys

private struct LiquidGlassKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue = Color(red: 0.45, green: 0.25, blue: 0.85)
}

private struct ThemeSecondaryKey: EnvironmentKey {
    static let defaultValue = Color(red: 0.55, green: 0.25, blue: 0.90)
}

extension EnvironmentValues {
    var isLiquidGlass: Bool {
        get { self[LiquidGlassKey.self] }
        set { self[LiquidGlassKey.self] = newValue }
    }
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
    var themeSecondary: Color {
        get { self[ThemeSecondaryKey.self] }
        set { self[ThemeSecondaryKey.self] = newValue }
    }
}

// MARK: - Glass Card

struct GlassCardModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(scheme == .dark ? 0.09 : 0.5), location: 0),
                                            .init(color: .white.opacity(scheme == .dark ? 0.03 : 0.1), location: 0.45),
                                            .init(color: .clear, location: 1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(scheme == .dark ? 0.18 : 0.65),
                                            .white.opacity(scheme == .dark ? 0.04 : 0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.22 : 0.06),
                        radius: 16, x: 0, y: 8)
        } else {
            content
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Glass Task Row

struct GlassTaskRowModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    let color: Color
    let isHighlighted: Bool
    let isCompleted: Bool

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isHighlighted
                                        ? color.opacity(0.15)
                                        : isCompleted
                                            ? color.opacity(0.04)
                                            : Color.white.opacity(scheme == .dark ? 0.04 : 0.3)
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    isHighlighted
                                        ? color.opacity(0.6)
                                        : Color.white.opacity(scheme == .dark ? 0.1 : 0.4),
                                    lineWidth: isHighlighted ? 1.5 : 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.15 : 0.04),
                        radius: 8, x: 0, y: 4)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isHighlighted
                              ? color.opacity(0.18)
                              : (isCompleted ? color.opacity(0.05) : Color(.systemBackground)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isHighlighted ? color : Color.clear, lineWidth: 2)
                )
                .shadow(color: .black.opacity(isCompleted ? 0.03 : 0.07), radius: 4, y: 2)
        }
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeaderModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    let color: Color

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    ZStack {
                        LinearGradient(
                            colors: [color.opacity(0.6), color.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Rectangle().fill(.ultraThinMaterial.opacity(0.35))
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        } else {
            content
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Glass Tab Button

struct GlassTabModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    let isSelected: Bool
    let color: Color

    func body(content: Content) -> some View {
        if isGlass {
            content
                .foregroundColor(isSelected ? .white : .secondary)
                .background {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(color.opacity(scheme == .dark ? 0.6 : 0.8))
                            .overlay {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
                            }
                    } else {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule(style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(scheme == .dark ? 0.05 : 0.35),
                                                .white.opacity(scheme == .dark ? 0.01 : 0.08)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        .white.opacity(scheme == .dark ? 0.08 : 0.25),
                                        lineWidth: 0.5
                                    )
                            }
                    }
                }
                .shadow(color: isSelected ? color.opacity(0.2) : .clear,
                        radius: 6, x: 0, y: 3)
        } else {
            content
                .background(isSelected ? color : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .secondary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Glass Date Cell

struct GlassDateCellModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    @Environment(\.themeAccent) private var accent
    @Environment(\.themeSecondary) private var secondary
    let isSelected: Bool
    let isToday: Bool

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent.opacity(scheme == .dark ? 0.65 : 0.85))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .clear],
                                            startPoint: .top,
                                            endPoint: .center
                                        )
                                    )
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
                            }
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(accent.opacity(0.4), lineWidth: 1.5)
                            }
                    } else {
                        Color.clear
                    }
                }
                .shadow(color: isSelected ? accent.opacity(0.25) : .clear,
                        radius: 8, x: 0, y: 4)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected
                              ? LinearGradient(colors: [accent, secondary],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [.clear, .clear],
                                               startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday && !isSelected ? accent.opacity(0.5) : .clear,
                                lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Glass Header

struct GlassHeaderModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.themeAccent) private var accent
    @Environment(\.themeSecondary) private var secondary

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    ZStack {
                        LinearGradient(
                            colors: [accent.opacity(0.6), secondary.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Rectangle().fill(.ultraThinMaterial.opacity(0.4))
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        } else {
            content
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.85), secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Glass Add Button

struct GlassAddButtonModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    let color: Color

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(color.opacity(scheme == .dark ? 0.08 : 0.06))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            color.opacity(0.3),
                                            .white.opacity(scheme == .dark ? 0.08 : 0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                }
        } else {
            content
                .background(color.opacity(0.1))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Glass Quick Stat

struct GlassQuickStatModifier: ViewModifier {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        if isGlass {
            content
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(scheme == .dark ? 0.07 : 0.4), location: 0),
                                            .init(color: .clear, location: 0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    .white.opacity(scheme == .dark ? 0.12 : 0.5),
                                    lineWidth: 0.5
                                )
                        }
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.18 : 0.04),
                        radius: 10, x: 0, y: 5)
        } else {
            content
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
    }
}

// MARK: - Glass App Background

struct GlassAppBackground: View {
    @Environment(\.isLiquidGlass) private var isGlass
    @Environment(\.colorScheme) private var scheme
    @Environment(\.themeAccent) private var accent

    var body: some View {
        if isGlass {
            ZStack {
                Color(.systemGroupedBackground)
                LinearGradient(
                    stops: [
                        .init(color: accent.opacity(scheme == .dark ? 0.06 : 0.04), location: 0),
                        .init(color: .clear, location: 0.4),
                        .init(color: accent.opacity(scheme == .dark ? 0.03 : 0.02), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        } else {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }
}

// MARK: - View Extensions

extension View {
    func glassCard() -> some View {
        modifier(GlassCardModifier())
    }
    func glassTaskRow(color: Color, isHighlighted: Bool, isCompleted: Bool) -> some View {
        modifier(GlassTaskRowModifier(color: color, isHighlighted: isHighlighted, isCompleted: isCompleted))
    }
    func glassSectionHeader(color: Color) -> some View {
        modifier(GlassSectionHeaderModifier(color: color))
    }
    func glassTab(isSelected: Bool, color: Color) -> some View {
        modifier(GlassTabModifier(isSelected: isSelected, color: color))
    }
    func glassDateCell(isSelected: Bool, isToday: Bool) -> some View {
        modifier(GlassDateCellModifier(isSelected: isSelected, isToday: isToday))
    }
    func glassHeader() -> some View {
        modifier(GlassHeaderModifier())
    }
    func glassAddButton(color: Color) -> some View {
        modifier(GlassAddButtonModifier(color: color))
    }
    func glassQuickStat() -> some View {
        modifier(GlassQuickStatModifier())
    }
}
