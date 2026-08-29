import SwiftUI

struct ContentView: View {
    @State private var game = GameStats()
    @State private var showingResetConfirmation = false
    @State private var showingAdvanceConfirmation = false
    @State private var navigateToDiagram = false
    @State private var navigateToSavedSets = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Double-tap any button to confirm its action.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    gameInfoCard
                    statsGrid
                    assistCard
                    serveCard
            DoubleTapButton(action: { navigateToDiagram = true }) {
                Text("View Stats Diagram")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .accessibilityHint("Double-tap to open the stats diagram")
        }
        DoubleTapButton(action: { navigateToSavedSets = true }) {
            Text("View Saved Sets")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .accessibilityHint("Double-tap to open the saved sets review")
    }
    .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Setter Stats")
            .navigationDestination(isPresented: $navigateToDiagram) {
                StatsDiagramView(game: game)
            }
            .navigationDestination(isPresented: $navigateToSavedSets) {
                SavedSetsReviewView(game: game)
            }
            .onAppear {
                game = GameStats.load()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DoubleTapButton(action: { game.undoLastAction() }) {
                        Label("Go Back", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!game.canUndo)
                    .accessibilityHint("Double-tap to undo the last action")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    DoubleTapButton(action: { showingResetConfirmation = true }) {
                        Text("Reset")
                    }
                    .disabled(game == GameStats())
                    .tint(.red)
                    .accessibilityHint("Double-tap to reset this game")
                }
            }
            .confirmationDialog("Reset this game?", isPresented: $showingResetConfirmation) {
                Button("Reset Everything", role: .destructive) {
                    game.reset()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Save Set \(game.setNumber)?", isPresented: $showingAdvanceConfirmation) {
                if game.canFinalizeCurrentSet {
                    Button("Save & Advance to Set \(game.setNumber + 1)") {
                        game.finalizeCurrentSet()
                    }
                } else {
                    Button("Save Set \(game.setNumber) & Finish Match") {
                        game.finalizeCurrentSet()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if game.canFinalizeCurrentSet {
                    Text("This stores Set \(game.setNumber)'s stats, resets all counters, and moves to the next set. Cancel keeps you on the current set.")
                } else {
                    Text("This is the final set. Saving stores Set \(game.setNumber)'s stats and resets all counters. Cancel keeps you on the current set.")
                }
            }
        }
    }

    private var gameInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GAME INFO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(game.savedSets.isEmpty ? "No sets saved on this iPhone yet" : "Saved on this iPhone · \(game.savedSets.count) set\(game.savedSets.count == 1 ? "" : "s")")
                .font(.footnote.weight(.medium))
                .foregroundStyle(game.savedSets.isEmpty ? .secondary : .blue)
            VStack(alignment: .leading, spacing: 7) {
                Text("Opponent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Opponent team name", text: Binding(
                    get: { game.opponent },
                    set: { game.setOpponent($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.words)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Set Number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    DoubleTapButton(action: { game.decrementSetNumber() }) {
                        Image(systemName: "minus")
                            .font(.headline.weight(.bold))
                            .frame(width: 48, height: 40)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Decrease set number")
                    .accessibilityHint("Double-tap to go back one set without losing saved data")
                    Text("\(game.setNumber)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                    Text("\(game.savedSets.count) saved")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                DoubleTapButton(action: { showingAdvanceConfirmation = true }) {
                    if game.canFinalizeCurrentSet {
                        Label("Save Set \(game.setNumber) & Advance", systemImage: "arrow.forward")
                    } else {
                        Label("Save Set \(game.setNumber) & Finish", systemImage: "checkmark")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .accessibilityHint(game.canFinalizeCurrentSet ? "Double-tap to save the current set and move to the next set" : "Double-tap to save the final set and finish the match")
                .disabled(!game.canFinalizeCurrentSet && game.savedSets.contains { $0.setNumber == game.setNumber })
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var statsGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach([Stat.attacks, .digs, .errors, .serviceErrors]) { stat in
                StatCard(
                    title: stat.rawValue,
                    value: game.value(for: stat),
                    tint: tint(for: stat),
                    decrement: { game.decrement(stat) },
                    increment: { game.increment(stat) }
                )
            }
        }
    }

    private var assistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ASSIST QUALITY BY SET LOCATION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                ForEach(AssistQuality.allCases) { quality in
                    HStack(spacing: 5) {
                        Text("\(quality.code)")
                            .font(.caption.weight(.bold))
                            .padding(5)
                            .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 6))
                        Text(quality.rawValue)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(AssistLocation.allCases) { location in
                    AssistRowView(location: location, game: $game)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var serveCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SERVES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                QualityCell(title: "Total Serves", value: game.serves, tint: .blue, decrement: { game.decrement(.serves) }, increment: { game.increment(.serves) })
                VStack(spacing: 7) {
                    Text("Aces")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(game.aces)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                    DoubleTapButton(action: { game.recordAce() }) {
                        Text("ACE")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .accessibilityLabel("Record an ace serve")
                    .accessibilityHint("Double-tap to record an ace")
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 7) {
                    Text("Service Errors")
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 30)
                        .foregroundStyle(.secondary)
                    Text("\(game.serviceErrors)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    DoubleTapButton(action: { game.recordServiceError() }) {
                        Text("ERROR")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel("Record a service error")
                    .accessibilityHint("Double-tap to record a service error")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func tint(for stat: Stat) -> Color {
        switch stat {
        case .attacks: return .red
        case .serves: return .blue
        case .digs: return .cyan
        case .errors, .serviceErrors: return .red
        }
    }
}

private struct StatsDiagramView: View {
    let game: GameStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("STATS OVERVIEW")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if game.savedSets.isEmpty {
                    Text("Cumulative totals for the current set (no sets saved yet).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Cumulative across \(game.savedSets.count) saved set\(game.savedSets.count == 1 ? "" : "s") plus the current set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                StatsChart(game: game)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Stats Diagram")
    }
}

private struct SavedSetsReviewView: View {
    let game: GameStats

    private var orderedSets: [SetRecord] { game.savedSets.reversed() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Every saved set is listed individually below. This is a local record on this iPhone — no cloud sync.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Newest saved sets listed first — \(game.savedSets.count) set\(game.savedSets.count == 1 ? "" : "s") total")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                currentSetCard

                if game.savedSets.isEmpty {
                    Text("No sets have been saved yet. Use the + button on the tracker to save a set, then it will appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(orderedSets.enumerated()), id: \.offset) { _, record in
                        savedSetCard(record)
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Saved Sets")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DoubleTapButton(action: { dismiss() }) {
                    Label("Back to Tracker", systemImage: "arrow.backward")
                }
                .accessibilityHint("Double-tap to return to the tracker")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private var currentSetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURRENT UNSAVED SET — WHAT WILL BE SAVED NEXT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Text(game.opponent.isEmpty ? "(no opponent entered)" : game.opponent)
                    .font(.title3.weight(.bold))
                Spacer()
                Text("Set \(game.setNumber)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            statsLine(attacks: game.attacks, digs: game.digs, errors: game.errors, serves: game.serves, aces: game.aces, serviceErrors: game.serviceErrors)
            Text("ASSISTS BY LOCATION & QUALITY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            assistsGrid(game.assistValue)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func savedSetCard(_ record: SetRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SET \(record.setNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack {
                Text(record.opponent.isEmpty ? "Unknown opponent" : record.opponent)
                    .font(.title3.weight(.bold))
                Spacer()
                Text("Set \(record.setNumber)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            statsLine(attacks: record.attacks, digs: record.digs, errors: record.errors, serves: record.serves, aces: record.aces, serviceErrors: record.serviceErrors)
            Text("ASSISTS BY LOCATION & QUALITY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            assistsGrid(record.assistValue)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func statsLine(attacks: Int, digs: Int, errors: Int, serves: Int, aces: Int, serviceErrors: Int) -> some View {
        HStack(spacing: 14) {
            statPill("Attacks", attacks)
            statPill("Digs", digs)
            statPill("Errors", errors)
            statPill("Serves", serves)
            statPill("Aces", aces)
            statPill("Svc Err", serviceErrors)
        }
        .font(.caption)
    }

    private func statPill(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
    }

    private func assistsGrid(_ value: (AssistLocation, AssistQuality) -> Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("")
                    .frame(width: 92, alignment: .leading)
                ForEach(AssistQuality.allCases) { quality in
                    Text("\(quality.code)")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(AssistLocation.allCases) { location in
                HStack(spacing: 8) {
                    Text(location.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                    ForEach(AssistQuality.allCases) { quality in
                        Text("\(value(location, quality))")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}

private struct StatsChart: View {
    let game: GameStats

    private var groups: [(String, [(value: Int, label: String, color: Color)])] {
        var result: [(String, [(Int, String, Color)])] = []
        result.append(("Attacks", [(game.cumulativeValue(for: .attacks), "Attacks", .red)]))
        for location in AssistLocation.allCases {
            let items = AssistQuality.allCases.map { quality -> (Int, String, Color) in
                let value = game.cumulativeAssist(location: location, quality: quality)
                let color: Color = {
                    switch quality {
                    case .perfect: return .blue
                    case .decent: return .gray
                    case .offTheMark: return .red
                    }
                }()
                return (value, quality.rawValue, color)
            }
            result.append((location.rawValue, items))
        }
        result.append(("Serves", [
            (game.cumulativeValue(for: .serves), "Total Serves", .blue),
            (game.cumulativeValue(for: .aces), "Aces", .cyan),
            (game.cumulativeValue(for: .serviceErrors), "Service Errors", .red)
        ]))
        result.append(("Digs", [(game.cumulativeValue(for: .digs), "Digs", .cyan)]))
        result.append(("Errors", [(game.cumulativeValue(for: .errors), "Errors", .red)]))
        return result
    }

    private var maxValue: Int {
        max(1, groups.flatMap { $0.1 }.map { $0.value }.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 9) {
                    Text(group.0.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(group.1, id: \.label) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.label)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(item.value)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(.systemFill))
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(item.color)
                                        .frame(width: geo.size.width * CGFloat(item.value) / CGFloat(maxValue))
                                }
                            }
                            .frame(height: 16)
                        }
                    }
                }
            }
        }
    }
}

private struct AssistRowView: View {
    let location: AssistLocation
    @Binding var game: GameStats

    private var rowTotal: Int {
        AssistQuality.allCases.reduce(0) { $0 + game.assistValue(location: location, quality: $1) }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(location.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            ForEach(AssistQuality.allCases) { quality in
                DoubleTapButton(action: { game.recordAssist(location: location, quality: quality) }) {
                    Text("\(quality.code)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(location.rawValue) \(quality.rawValue)")
                .accessibilityHint("Double-tap to record a \(quality.rawValue.lowercased()) assist")
            }
            Text("\(rowTotal)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

private struct QualityCell: View {
    let title: String
    let value: Int
    let tint: Color
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 30)
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            HStack(spacing: 5) {
                StepButton(symbol: "minus", action: decrement, accessibilityLabel: "Decrease \(title)")
                StepButton(symbol: "plus", action: increment, accessibilityLabel: "Increase \(title)")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatCard: View {
    let title: String
    let value: Int
    let tint: Color
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            HStack(spacing: 10) {
                StepButton(symbol: "minus", action: decrement, accessibilityLabel: "Decrease \(title)")
                StepButton(symbol: "plus", action: increment, accessibilityLabel: "Increase \(title)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DoubleTapButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: {}, label: label)
            .simultaneousGesture(TapGesture(count: 2).onEnded(action))
    }
}

private struct StepButton: View {
    let symbol: String
    let action: () -> Void
    let accessibilityLabel: String

    var body: some View {
        DoubleTapButton(action: action) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .frame(width: 48, height: 40)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to change this value")
    }
}

#Preview {
    ContentView()
}
