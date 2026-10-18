import SwiftUI

struct StrategyView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    planCard
                    patternCard
                    warningCard
                    ForEach(clips) { clip in
                        clipCard(clip)
                    }
                    Text("Team numbers and the final score were not readable in these clips, so nothing was written into Scout.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .vexScreen()
            .navigationTitle("Strategy")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("What we should do")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("From the four match videos")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Match plan", systemImage: "list.number")
                .font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(VexLook.red, in: Circle())
                    Text(step)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .vexCard()
    }

    private var steps: [String] {
        [
            "Pick one wall before the match and drive straight to it.",
            "Score one load, then back straight out. Leave the wall before you tip or get stuck.",
            "If your wall is blocked when you arrive, turn around and take the other wall.",
            "After the middle is empty, stay on your wall. Crossing the field is how you end up in a pile.",
            "If you jam, stop driving forward and back out. Keep scoring on the open side of your goal.",
            "In the last 20 seconds, finish the stack you already have."
        ]
    }

    private var patternCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("What scores", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(VexLook.green)
            Text("Own a wall goal and stack on it. The middle of the field gets cleared early. The points in these matches are on the left and right walls.")
                .font(.body)
        }
        .vexCard()
    }

    private var warningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Watch the right wall", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(VexLook.amber)
            Text("Robots score on the right wall, then get stuck, tipped, or tangled. Back out before the robot high-centers so it can go get another load.")
                .font(.body)
        }
        .vexCard()
    }

    private func clipCard(_ clip: MatchClip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(clip.name)
                    .font(.headline)
                Spacer()
                Text(clip.length)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(clip.note)
                .font(.body)
        }
        .vexCard()
    }

    private var clips: [MatchClip] {
        [
            MatchClip(
                name: "IMG 1595",
                length: "2:40",
                note: "Both sides build stacks. Late in the match the right-side robots bunch up on the blue goal, and one looks tipped or tangled."
            ),
            MatchClip(
                name: "IMG 1604",
                length: "2:24",
                note: "The left robot builds a tall stack with a lift. The right robot works its goal, then looks boxed in and stops moving much."
            ),
            MatchClip(
                name: "IMG 1611",
                length: "2:38",
                note: "The right robot is the main scorer, then ends up jammed against the right wall. The left robot stays smaller and less active."
            ),
            MatchClip(
                name: "IMG 1615",
                length: "3:12",
                note: "A robot drives through the center while both walls get scored. The clip runs past the buzzer, and people walk onto the field at the end."
            )
        ]
    }
}

private struct MatchClip: Identifiable {
    var name: String
    var length: String
    var note: String
    var id: String { name }
}
