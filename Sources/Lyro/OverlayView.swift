import SwiftUI

/// The translucent overlay card. Renders either karaoke-style lyrics
/// (previous / current / next) or a single status message.
struct OverlayView: View {
    @EnvironmentObject var vm: LyricsViewModel
    @EnvironmentObject var settings: OverlaySettings

    /// Everything is sized in points and multiplied by this so the card scales
    /// uniformly with the window (which AppDelegate resizes by the same factor).
    private var s: CGFloat { CGFloat(settings.scale) }

    var body: some View {
        VStack(spacing: 8 * s) {
            if settings.showTrackName && !vm.headerText.isEmpty {
                Text(vm.headerText)
                    .font(.system(size: 12 * s, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .id(vm.headerText)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer(minLength: 0)

            if vm.mode == .lyrics {
                lyricsBody
            } else {
                Text(vm.message)
                    .font(.system(size: 17 * s, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .id(vm.message)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30 * s)
        .padding(.vertical, 16 * s)
        .background(
            RoundedRectangle(cornerRadius: 22 * s, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(settings.backgroundOpacity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22 * s, style: .continuous)
                .strokeBorder(.white.opacity(0.12 * settings.backgroundOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22 * s, style: .continuous))
        .shadow(color: .black.opacity(0.35 * settings.backgroundOpacity), radius: 18 * s, y: 8 * s)
        .padding(10 * s)
        .animation(.easeOut(duration: 0.18), value: settings.backgroundOpacity)
        .animation(.easeInOut(duration: 0.22), value: settings.showTrackName)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: vm.message)
        .animation(.easeInOut(duration: 0.25), value: vm.headerText)
    }

    // MARK: - Lyrics

    private var lyricsBody: some View {
        VStack(spacing: 7 * s) {
            adjacentLine(vm.previousLine)
            currentLine
            adjacentLine(vm.nextLine)
        }
        // Drive every line's insert/remove transition from the active line change.
        .animation(.spring(response: 0.42, dampingFraction: 0.80), value: vm.currentLine)
    }

    /// The highlighted, karaoke-style active line: a gradient pop-in that slides
    /// up as the song advances.
    private var currentLine: some View {
        ZStack {
            Text(vm.currentLine ?? "♪")
                .font(.system(size: 28 * s, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.55), radius: 4 * s, y: 1)
                .shadow(color: .white.opacity(0.18 * settings.backgroundOpacity), radius: 8 * s)
                .frame(maxWidth: .infinity)
                .id(vm.currentLine)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.90, anchor: .bottom)),
                    removal: .move(edge: .top)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.96, anchor: .top))
                ))
        }
        .frame(maxWidth: .infinity)
    }

    /// The dimmed previous / next context lines, with a softer slide transition.
    @ViewBuilder
    private func adjacentLine(_ text: String?) -> some View {
        ZStack {
            if let text {
                Text(text.isEmpty ? "♪" : text)
                    .font(.system(size: 15 * s, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.55), radius: 3 * s, y: 1)
                    .frame(maxWidth: .infinity)
                    .id(text)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 19 * s)
    }
}
