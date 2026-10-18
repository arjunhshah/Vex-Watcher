import SwiftUI

enum VexLook {
    static let red = Color(red: 0.78, green: 0.09, blue: 0.18)
    static let blue = Color(red: 0.05, green: 0.35, blue: 0.72)
    static let ink = Color(red: 0.10, green: 0.07, blue: 0.08)
    static let green = Color(red: 0.00, green: 0.52, blue: 0.32)
    static let amber = Color(red: 0.86, green: 0.42, blue: 0.05)

    static func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "Elite": return red
        case "Strong": return green
        case "Good": return blue
        case "Average": return amber
        default: return .secondary
        }
    }
}

extension TeamReport {
    var tint: Color { VexLook.gradeColor(grade) }
}

struct GradePill: View {
    var grade: String
    var onDark = false

    var body: some View {
        Text(grade.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(onDark ? Color.white.opacity(0.16) : VexLook.gradeColor(grade).opacity(0.16), in: Capsule())
            .foregroundStyle(onDark ? Color.white : VexLook.gradeColor(grade))
    }
}

struct ScorePlate: View {
    var percent: Int
    var grade: String
    var caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(percent)%")
                .font(.system(size: 58, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                GradePill(grade: grade, onDark: true)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VexLook.red, VexLook.ink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120, height: 120)
                .offset(x: 36, y: -46)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PercentBar: View {
    var name: String
    var percent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(percent)%")
                    .monospacedDigit()
            }
            .font(.caption.weight(.medium))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(VexLook.red)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, percent))) / 100)
                }
            }
            .frame(height: 7)
        }
    }
}

extension View {
    private var screenWash: Color {
        #if os(iOS)
        Color(.systemGroupedBackground)
        #else
        Color.black
        #endif
    }

    func vexScreen() -> some View {
        background {
            LinearGradient(
                colors: [VexLook.red.opacity(0.16), screenWash],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    func vexCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
