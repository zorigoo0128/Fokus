import SwiftUI


// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : (isHovering ? 1.04 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .glassEffect(isHovering ? .regular : .clear)
    }
}

// MARK: - Circular Progress Bar
struct CircularProgressView: View {
    var progress: Double // 0.0 to 1.0
    var size: CGFloat = 340
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            // Ambient Outer Glow
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: lineWidth + 16)
                .blur(radius: 8)
                .frame(width: size, height: size)

            // Background Frosted Track
            Circle()
                .stroke(
                    Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)

            // Active Glowing Progress Track
            Circle()
                .trim(from: 0.0, to: CGFloat(max(0.001, progress)))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.8, green: 0.95, blue: 1.0),
                            Color(red: 0.5, green: 0.8, blue: 1.0),
                            Color(red: 0.75, green: 0.65, blue: 1.0),
                            Color(red: 0.9, green: 0.95, blue: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.6, green: 0.85, blue: 1.0).opacity(0.7), radius: 8, x: 0, y: 0)
                .animation(.linear(duration: 0.2), value: progress)

            // Indicator bead at the progress point
            GeometryReader { geo in
                let radius = size / 2
                let angle = Angle.degrees(progress * 360 - 90)
                let x = geo.size.width / 2 + radius * cos(CGFloat(angle.radians))
                let y = geo.size.height / 2 + radius * sin(CGFloat(angle.radians))

                Circle()
                    .fill(Color.white)
                    .frame(width: lineWidth + 4, height: lineWidth + 4)
                    .shadow(color: Color.white, radius: 6, x: 0, y: 0)
                    .position(x: x, y: y)
                    .opacity(progress > 0.01 ? 1.0 : 0.0)
                    .animation(.linear(duration: 0.2), value: progress)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Volume Slider Pill
struct GlassVolumeSlider: View {
    @Binding var volume: Double
    @Binding var isMuted: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted || volume == 0 ? "speaker.slash.fill" : (volume > 0.5 ? "speaker.wave.3.fill" : "speaker.wave.1.fill"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isMuted ? .red.opacity(0.9) : .white.opacity(0.9))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 90)
                .accentColor(.white)
                .onChange(of: volume) { _, newVol in
                    if newVol > 0 && isMuted {
                        isMuted = false
                    }
                }

            Text("\(Int((isMuted ? 0 : volume) * 100))%")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(isHovering ? .regular : .clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Ambient Fallback Mesh
struct AmbientAuroraView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [Color(red: 0.15, green: 0.2, blue: 0.45).opacity(0.6), .clear],
                center: animate ? .topLeading : .bottomTrailing,
                startRadius: 50,
                endRadius: 600
            )

            RadialGradient(
                colors: [Color(red: 0.35, green: 0.12, blue: 0.4).opacity(0.5), .clear],
                center: animate ? .bottomLeading : .topTrailing,
                startRadius: 100,
                endRadius: 700
            )

            RadialGradient(
                colors: [Color(red: 0.1, green: 0.35, blue: 0.4).opacity(0.4), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}
