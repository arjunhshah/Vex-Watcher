import SwiftUI

extension TeamReport {
    var tint: Color {
        switch grade {
        case "Elite":
            return Color(red: 0.78, green: 0.09, blue: 0.18)
        case "Strong":
            return Color(red: 0.00, green: 0.52, blue: 0.32)
        case "Good":
            return Color(red: 0.00, green: 0.42, blue: 0.72)
        case "Average":
            return Color(red: 0.86, green: 0.42, blue: 0.05)
        default:
            return .secondary
        }
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
            .font(.caption)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(min(100, max(0, percent))) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}
