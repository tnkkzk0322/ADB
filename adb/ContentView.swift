import SwiftUI

struct ContentView: View {
    private let library = ScriptLibrary.loadFromBundle()
    private let saveStore = SaveStore()
    @State private var screen: AppScreen = .home

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
            .ignoresSafeArea()

            BackgroundOrnament()
                .ignoresSafeArea()

            switch screen {
            case .home:
                HomeView(stories: library.stories, saveStore: saveStore) { storyId, startMode in
                    screen = .story(storyId, startMode)
                }
            case .story(let storyId, let startMode):
                if let story = story(id: storyId) {
                    let initialSceneId = startMode.resolveSceneId(for: story, saveStore: saveStore)
                    StoryPlayerView(
                        story: story,
                        initialSceneId: initialSceneId,
                        saveStore: saveStore,
                        onExit: { screen = .home },
                        onThanks: { screen = .thanks(storyId) }
                    )
                }
            case .thanks(let storyId):
                if let story = story(id: storyId) {
                    ThanksView(story: story) {
                        screen = .home
                    }
                }
            }
        }
    }

    private func story(id: String) -> Story? {
        library.stories.first { $0.id == id }
    }
}

private enum AppScreen: Equatable {
    case home
    case story(String, StoryStartMode)
    case thanks(String)
}

private enum AppTheme {
    static let backgroundTop = Color(red: 0.08, green: 0.11, blue: 0.16)
    static let backgroundBottom = Color(red: 0.17, green: 0.16, blue: 0.24)
    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let surface = Color.white.opacity(0.08)
    static let surfaceStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.2)
    static let strokeSoft = Color.white.opacity(0.14)
    static let shadow = Color.black.opacity(0.35)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.55)

    static let accentBlue = Color(red: 0.55, green: 0.75, blue: 0.95)
    static let accentPeach = Color(red: 0.95, green: 0.65, blue: 0.5)
    static let accentViolet = Color(red: 0.75, green: 0.6, blue: 0.95)
}

private enum AppTypography {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

private struct AppSurface: View {
    let cornerRadius: CGFloat
    let fill: Color
    let stroke: Color
    let shadow: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    init(
        cornerRadius: CGFloat,
        fill: Color = AppTheme.surface,
        stroke: Color = AppTheme.stroke,
        shadow: Color = AppTheme.shadow,
        shadowRadius: CGFloat = 16,
        shadowY: CGFloat = 10
    ) {
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.stroke = stroke
        self.shadow = shadow
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .shadow(color: shadow, radius: shadowRadius, x: 0, y: shadowY)
    }
}

private enum StoryStartMode: Equatable {
    case beginning
    case continueFromSave

    func resolveSceneId(for story: Story, saveStore: SaveStore) -> String {
        switch self {
        case .beginning:
            return story.startSceneId
        case .continueFromSave:
            return saveStore.loadSceneId(for: story.id) ?? story.startSceneId
        }
    }
}

private struct HomeView: View {
    let stories: [Story]
    let saveStore: SaveStore
    let onSelect: (String, StoryStartMode) -> Void
    @State private var selectedStory: Story?

    var body: some View {
        let savedSceneIdMap = Dictionary(uniqueKeysWithValues: stories.map { story in
            (story.id, saveStore.loadSceneId(for: story.id))
        })

        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("ADB VISUAL")
                    .font(AppTypography.display(26))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Select a story to begin")
                    .font(AppTypography.ui(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(stories) { story in
                        StoryCard(
                            story: story,
                            savedSceneId: savedSceneIdMap[story.id] ?? nil,
                            onSelect: {
                                selectedStory = story
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .padding(.bottom, 16)
        .sheet(item: $selectedStory) { story in
            StoryStartSheet(
                story: story,
                savedSceneId: savedSceneIdMap[story.id] ?? nil,
                onStart: { mode in
                    onSelect(story.id, mode)
                    selectedStory = nil
                },
                onCancel: { selectedStory = nil }
            )
        }
    }
}

private struct StoryCard: View {
    let story: Story
    let savedSceneId: String?
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(story.title)
                    .font(AppTypography.ui(18))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(story.description)
                    .font(AppTypography.ui(13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                if let savedSceneId {
                    Text("Saved: \(savedSceneId)")
                        .font(AppTypography.ui(11, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                AppSurface(cornerRadius: 20, fill: AppTheme.surface, stroke: AppTheme.strokeSoft, shadowRadius: 12, shadowY: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StoryStartSheet: View {
    let story: Story
    let savedSceneId: String?
    let onStart: (StoryStartMode) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            BackgroundOrnament()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(story.title)
                        .font(AppTypography.display(22))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Choose how to start")
                        .font(AppTypography.ui(13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                VStack(spacing: 12) {
                    Button(action: { onStart(.beginning) }) {
                        SheetActionRow(
                            title: "START",
                            subtitle: "Begin from the first scene",
                            systemImage: "play.fill",
                            isEmphasized: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { onStart(.continueFromSave) }) {
                        SheetActionRow(
                            title: "LOAD",
                            subtitle: savedSceneId == nil ? "No save data found" : "Continue from your last scene",
                            systemImage: "arrow.triangle.2.circlepath",
                            isEmphasized: false
                        )
                        .opacity(savedSceneId == nil ? 0.5 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(savedSceneId == nil)
                }

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppTypography.ui(12, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppTheme.surfaceStrong)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(
                AppSurface(
                    cornerRadius: 24,
                    fill: Color.black.opacity(0.35),
                    stroke: AppTheme.strokeSoft,
                    shadow: AppTheme.shadow,
                    shadowRadius: 18,
                    shadowY: 12
                )
            )
            .padding(.horizontal, 16)
        }
        .presentationDetents([.height(360)])
        .presentationBackground(.clear)
    }
}

private struct SheetActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isEmphasized: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.ui(14))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(AppTypography.ui(11, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Image(systemName: systemImage)
                .font(AppTypography.ui(14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            AppSurface(
                cornerRadius: 16,
                fill: isEmphasized ? AppTheme.surfaceStrong : AppTheme.surface,
                stroke: AppTheme.strokeSoft,
                shadow: AppTheme.shadow,
                shadowRadius: 10,
                shadowY: 6
            )
        )
    }
}

private struct StoryPlayerView: View {
    let story: Story
    let initialSceneId: String
    let saveStore: SaveStore
    let onExit: () -> Void
    let onThanks: () -> Void

    @State private var currentSceneId: String
    @State private var currentLineIndex = 0
    @State private var isSaveAlertPresented = false
    @State private var isHistoryPresented = false
    @State private var history: [HistoryEntry] = []
    init(
        story: Story,
        initialSceneId: String,
        saveStore: SaveStore,
        onExit: @escaping () -> Void,
        onThanks: @escaping () -> Void
    ) {
        self.story = story
        self.initialSceneId = initialSceneId
        self.saveStore = saveStore
        self.onExit = onExit
        self.onThanks = onThanks
        _currentSceneId = State(initialValue: initialSceneId)
    }

    private var currentScene: ScriptScene {
        story.scene(id: currentSceneId) ?? story.fallbackScene
    }

    private var currentLine: ScriptLine {
        let lines = currentScene.lines
        return lines[min(currentLineIndex, max(lines.count - 1, 0))]
    }

    private var isAtLineEnd: Bool {
        currentLineIndex >= max(currentScene.lines.count - 1, 0)
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let contentWidth = max(proxy.size.width - 40, 0)
            let stageWidth = min(contentWidth, 520)
            let panelWidth = min(contentWidth, 560)

            ZStack {
                if !currentScene.backgroundImageName.isEmpty {
                    Image(currentScene.backgroundImageName)
                        .scaledToFill()
                        .offset(y: -safeTop)
                        .clipped()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .overlay(Color.black.opacity(0.8))
                }
                
                VStack {
                    
                    Spacer()

                    HStack {
                        Spacer(minLength: 0)
                        CharacterStage(scene: currentScene)
                            .frame(width: stageWidth)
                        Spacer(minLength: 0)
                    }

                    Spacer()
                }

                VStack(spacing: 0) {
                    TopBar(
                        scene: currentScene,
                        storyTitle: story.title,
                        onExit: onExit,
                        onSave: saveCurrent,
                        onShowHistory: { isHistoryPresented = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, safeTop + 8)
                    .padding(.bottom, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.8), Color.black.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()

                    HStack {
                        Spacer(minLength: 0)
                        DialoguePanel(
                            line: currentLine,
                            scene: currentScene,
                            isAtLineEnd: isAtLineEnd,
                            onAdvance: advanceLine,
                            onSelectChoice: selectChoice,
                            onComplete: onThanks
                        )
                        .frame(width: panelWidth)
                        Spacer(minLength: 0)
                    }
                    
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .onChange(of: currentSceneId) { _, newValue in
                    currentLineIndex = 0
                    saveStore.saveSceneId(newValue, for: story.id)
                }
                .onAppear {
                    saveStore.saveSceneId(currentSceneId, for: story.id)
                }
                .alert("Progress saved", isPresented: $isSaveAlertPresented) {
                    Button("OK", role: .cancel) { }
                }
                .sheet(isPresented: $isHistoryPresented) {
                    HistorySheet(history: history)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
    }

    private func advanceLine() {
        guard currentLineIndex + 1 < currentScene.lines.count else { return }
        history.append(HistoryEntry(from: currentLine))
        currentLineIndex += 1
    }

    private func jumpToScene(_ sceneId: String) {
        currentSceneId = sceneId
    }

    private func selectChoice(_ choice: Choice) {
        history.append(HistoryEntry(from: choice))
        jumpToScene(choice.nextSceneId)
    }

    private func saveCurrent() {
        saveStore.saveSceneId(currentSceneId, for: story.id)
        isSaveAlertPresented = true
    }
}

private struct TopBar: View {
    let scene: ScriptScene
    let storyTitle: String
    let onExit: () -> Void
    let onSave: () -> Void
    let onShowHistory: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(AppTypography.ui(14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(storyTitle)
                    .font(AppTypography.ui(14))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                Text(scene.title)
                    .font(AppTypography.ui(12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            HStack(spacing: 8) {
                CapsuleButton(title: "Save", action: onSave)
                CapsuleButton(title: "History", action: onShowHistory)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct CapsuleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.ui(11))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(AppTheme.surfaceStrong)
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.stroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct InfoChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppTypography.ui(11))
            .foregroundStyle(AppTheme.textPrimary.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.surfaceStrong)
                    .overlay(
                        Capsule()
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
            )
    }
}

private struct CharacterStage: View {
    let scene: ScriptScene

    private let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
    private let accents: [Color] = [
        AppTheme.accentBlue,
        AppTheme.accentPeach,
        AppTheme.accentViolet
    ]
    private let horizontalPadding: CGFloat = 24
    private let verticalPadding: CGFloat = 20
    private let characterSpacing: CGFloat = 24

    var body: some View {
        ZStack {
            cardShape
                .fill(AppTheme.surface)
                .overlay(
                    cardShape
                        .stroke(AppTheme.strokeSoft, lineWidth: 1)
                )
                .shadow(color: AppTheme.shadow, radius: 22, x: 0, y: 16)


            GeometryReader { proxy in
                let characters = scene.characters.isEmpty ? [nil, nil] : scene.characters.map(Optional.some)
                let count = max(characters.count, 2)
                let layout = silhouetteLayout(
                    for: proxy.size.width,
                    count: count
                )

                HStack(spacing: layout.spacing) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                        CharacterSilhouette(
                            name: character?.name ?? "???",
                            imageName: character?.imageName ?? "",
                            accent: accents[index % accents.count],
                            cardSize: layout.size
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
        .frame(height: 280)
    }

    private func silhouetteLayout(for containerWidth: CGFloat, count: Int) -> (size: CGSize, spacing: CGFloat) {
        let availableWidth = containerWidth - (horizontalPadding * 2)
        let minWidth: CGFloat = count >= 3 ? 96 : 110
        let maxWidth: CGFloat = 170
        let itemCount = CGFloat(max(count, 1))
        let gapCount = CGFloat(max(count - 1, 0))

        var spacing = characterSpacing
        var width = (availableWidth - (spacing * gapCount)) / itemCount

        if width < minWidth, gapCount > 0 {
            let adjustedSpacing = (availableWidth - (minWidth * itemCount)) / gapCount
            spacing = min(characterSpacing, max(8, adjustedSpacing))
            width = (availableWidth - (spacing * gapCount)) / itemCount
        }

        let clampedWidth = min(maxWidth, max(minWidth, width))
        let clampedHeight = min(200, max(140, clampedWidth * 1.28))
        return (CGSize(width: clampedWidth, height: clampedHeight), spacing)
    }
}

private struct CharacterSilhouette: View {
    let name: String
    let imageName: String
    let accent: Color
    let cardSize: CGSize

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(accent.opacity(0.2))
                    .frame(width: cardSize.width, height: cardSize.height)

                if imageName.isEmpty {
                    Image(systemName: "person.fill")
                        .font(AppTypography.ui(max(46, cardSize.width * 0.45), weight: .regular))
                        .foregroundStyle(accent.opacity(0.7))
                } else {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(max(12, cardSize.width * 0.12))
                        .foregroundStyle(.white.opacity(0.95))
                }
            }

            Text(name.isEmpty ? "???" : name)
                .font(AppTypography.ui(max(12, cardSize.width * 0.1)))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

private struct DialoguePanel: View {
    let line: ScriptLine
    let scene: ScriptScene
    let isAtLineEnd: Bool
    let onAdvance: () -> Void
    let onSelectChoice: (Choice) -> Void
    let onComplete: () -> Void
    @State private var holdProgress = 0.0
    @State private var holdTimer: Timer?
    @State private var isChoicesVisible = false

    private let holdDuration = 0.9
    private enum HoldRequirement {
        case line
        case choice
    }

    private var singleChoice: Choice? {
        guard isAtLineEnd, scene.choices.count == 1 else { return nil }
        return scene.choices.first
    }

    private var isChoiceNarration: Bool {
        guard let choice = singleChoice else { return false }
        return choice.speaker.isEmpty
    }

    private var requiresHoldForLine: Bool {
        line.kind == .narration
    }

    private var requiresHoldForChoice: Bool {
        isChoiceNarration
    }

    private var shouldShowNamePlate: Bool {
        line.kind == .dialogue && !line.speaker.isEmpty
    }

    private var holdRequirement: HoldRequirement? {
        if isAtLineEnd, !scene.choices.isEmpty {
            if !isChoicesVisible {
                return requiresHoldForLine ? .line : nil
            }
            if singleChoice != nil {
                return requiresHoldForChoice ? .choice : nil
            }
            return nil
        }
        return requiresHoldForLine && !isAtLineEnd ? .line : nil
    }

    var body: some View {
        let holdGesture = DragGesture(minimumDistance: 0)
            .onChanged { _ in
                startHoldIfNeeded()
            }
            .onEnded { _ in
                stopHoldIfNeeded()
            }

        let hasChoices = !scene.choices.isEmpty
        let showChoices = isAtLineEnd && hasChoices && isChoicesVisible

        VStack(alignment: .leading, spacing: 14) {
            if !showChoices {
                if shouldShowNamePlate {
                    NamePlate(name: line.speaker)
                }

                Text(line.text)
                    .font(AppTypography.body(16, weight: requiresHoldForLine ? .regular : .medium))
                    .foregroundStyle(AppTheme.textPrimary.opacity(requiresHoldForLine ? 0.8 : 0.9))
                    .italic(requiresHoldForLine)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
            }

            if isAtLineEnd {
                if hasChoices {
                    if showChoices {
                        if let choice = singleChoice {
                            VStack(alignment: .leading, spacing: 10) {
                                if !choice.speaker.isEmpty {
                                    NamePlate(name: choice.speaker)
                                }
                                Text(choice.text)
                                    .font(AppTypography.body(16, weight: isChoiceNarration ? .regular : .medium))
                                    .foregroundStyle(AppTheme.textPrimary.opacity(isChoiceNarration ? 0.8 : 0.9))
                                    .italic(isChoiceNarration)
                                    .lineSpacing(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .allowsHitTesting(false)
                            }
                            if isChoiceNarration {
                                HintRow(requiresHold: true, progress: holdProgress)
                            }
                        } else {
                            ChoiceStack(choices: scene.choices, onSelect: onSelectChoice)
                        }
                    } else {
                        HintRow(requiresHold: requiresHoldForLine, progress: holdProgress)
                    }
                } else {
                    EndButton(onComplete: onComplete)
                }
            } else {
                HintRow(requiresHold: requiresHoldForLine, progress: holdProgress)
            }
        }
        .padding(16)
        .background(
            AppSurface(
                cornerRadius: 22,
                fill: Color.black.opacity(0.35),
                stroke: AppTheme.strokeSoft,
                shadow: AppTheme.shadow,
                shadowRadius: 18,
                shadowY: 10
            )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isAtLineEnd, hasChoices {
                if !isChoicesVisible {
                    if !requiresHoldForLine {
                        isChoicesVisible = true
                    }
                } else if let choice = singleChoice, !requiresHoldForChoice {
                    onSelectChoice(choice)
                }
            } else if !requiresHoldForLine {
                onAdvance()
            }
        }
        .simultaneousGesture(holdGesture)
        .onChange(of: line.id) { _, _ in
            resetChoiceState()
        }
        .onChange(of: scene.id) { _, _ in
            resetChoiceState()
        }
        .onDisappear {
            stopHold(reset: false)
        }
    }

    private func startHoldIfNeeded() {
        guard holdRequirement != nil else { return }
        if holdTimer != nil { return }

        let startTime = Date()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / holdDuration, 1)
            withAnimation(.linear(duration: 0.016)) {
                holdProgress = progress
            }
            if progress >= 1 {
                stopHold(reset: false)
                if isAtLineEnd, !scene.choices.isEmpty {
                    if !isChoicesVisible {
                        isChoicesVisible = true
                    } else if let choice = singleChoice {
                        onSelectChoice(choice)
                    }
                } else {
                    onAdvance()
                }
            }
        }
    }

    private func stopHoldIfNeeded() {
        guard holdRequirement != nil else { return }
        stopHold(reset: true)
    }

    private func resetHold() {
        stopHold(reset: false)
        holdProgress = 0
    }

    private func resetChoiceState() {
        isChoicesVisible = false
        resetHold()
    }

    private func stopHold(reset: Bool) {
        holdTimer?.invalidate()
        holdTimer = nil
        if reset {
            withAnimation(.easeOut(duration: 0.2)) {
                holdProgress = 0
            }
        }
    }
}

private struct EndButton: View {
    let onComplete: () -> Void

    var body: some View {
        Button(action: onComplete) {
            HStack {
                Text("Go to Credits")
                    .font(AppTypography.ui(14))
                    .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                Spacer()
                Image(systemName: "sparkles")
                    .font(AppTypography.ui(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                AppSurface(cornerRadius: 14, fill: AppTheme.surfaceStrong, stroke: AppTheme.strokeSoft, shadowRadius: 10, shadowY: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct NamePlate: View {
    let name: String

    var body: some View {
        Text(name)
            .font(AppTypography.ui(14, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.9))
            )
    }
}

private struct ChoiceStack: View {
    let choices: [Choice]
    let onSelect: (Choice) -> Void

    private var commonSpeaker: String? {
        guard let first = choices.first?.speaker, !first.isEmpty else { return nil }
        if choices.allSatisfy({ $0.speaker == first }) {
            return first
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let speaker = commonSpeaker {
                NamePlate(name: speaker)
            }
            ForEach(choices) { choice in
                ChoiceRow(
                    text: choice.text,
                    speaker: commonSpeaker == nil ? choice.speaker : ""
                ) {
                    onSelect(choice)
                }
            }
        }
    }
}

private struct ChoiceRow: View {
    let text: String
    let speaker: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if !speaker.isEmpty {
                        NamePlate(name: speaker)
                    }
                    Text(text)
                        .font(AppTypography.ui(14))
                        .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTypography.ui(12, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                AppSurface(cornerRadius: 14, fill: AppTheme.surface, stroke: AppTheme.strokeSoft, shadowRadius: 10, shadowY: 6)
            )
        }
        .buttonStyle(.plain)
    }
}


private struct HintRow: View {
    let requiresHold: Bool
    let progress: Double

    var body: some View {
        HStack {
            Spacer()
            if requiresHold {
                HoldProgressRing(progress: progress)
            } else {
                Image(systemName: "play.fill")
                    .font(AppTypography.ui(12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

private struct HoldProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.strokeSoft, lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AppTheme.textPrimary.opacity(0.85),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
    }
}

private struct HistoryEntry: Identifiable {
    let id = UUID()
    let text: String

    init(from line: ScriptLine) {
        if line.kind == .dialogue, !line.speaker.isEmpty {
            text = "\(line.speaker): \(line.text)"
        } else {
            text = line.text
        }
    }

    init(from choice: Choice) {
        if choice.speaker.isEmpty {
            text = "Choice: \(choice.text)"
        } else {
            text = "\(choice.speaker): \(choice.text)"
        }
    }
}

private struct ThanksView: View {
    let story: Story
    let onClose: () -> Void

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            BackgroundOrnament()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Text("Thank you")
                        .font(AppTypography.display(30))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(story.title)
                        .font(AppTypography.ui(14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Support this story if you enjoyed it.")
                        .font(AppTypography.ui(12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                VStack(spacing: 12) {
                    TipButton(amount: 100) { }
                    TipButton(amount: 500) { }
                    TipButton(amount: 1000, isFeatured: true) { }
                    TipButton(amount: 10000) { }
                }
                .padding(16)
                .background(
                    AppSurface(
                        cornerRadius: 20,
                        fill: Color.black.opacity(0.3),
                        stroke: AppTheme.strokeSoft,
                        shadow: AppTheme.shadow,
                        shadowRadius: 14,
                        shadowY: 8
                    )
                )

                Button(action: onClose) {
                    HStack {
                        Text("Back to Title")
                            .font(AppTypography.ui(13))
                            .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                        Spacer()
                        Image(systemName: "chevron.backward")
                            .font(AppTypography.ui(12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        TipButtonBackground(isFeatured: false)
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 36)
            .padding(.bottom, 16)
        }
    }
}

private struct TipButton: View {
    let amount: Int
    let isFeatured: Bool
    let action: () -> Void
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    init(amount: Int, isFeatured: Bool = false, action: @escaping () -> Void) {
        self.amount = amount
        self.isFeatured = isFeatured
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(formattedAmount)
                        .font(AppTypography.ui(16))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(isFeatured ? "Most supported" : "One-time support")
                        .font(AppTypography.ui(11, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppTheme.surfaceStrong)
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppTheme.textPrimary.opacity(isFeatured ? 1 : 0.85))
                }
                .frame(width: 26, height: 26)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                TipButtonBackground(isFeatured: isFeatured)
            )
        }
        .buttonStyle(.plain)
    }

    private var formattedAmount: String {
        let number = NSNumber(value: amount)
        let formatted = TipButton.formatter.string(from: number) ?? "\(amount)"
        return "¥\(formatted)"
    }
}

private struct TipButtonBackground: View {
    let isFeatured: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.accentPeach.opacity(isFeatured ? 0.3 : 0.18),
                            AppTheme.accentViolet.opacity(isFeatured ? 0.2 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: AppTheme.accentPeach.opacity(isFeatured ? 0.35 : 0.18),
                    radius: isFeatured ? 18 : 10,
                    x: 0,
                    y: 10
                )
            AppSurface(
                cornerRadius: 16,
                fill: AppTheme.surfaceStrong,
                stroke: AppTheme.strokeSoft,
                shadowRadius: 10,
                shadowY: 6
            )
        }
    }
}

private struct BackgroundOrnament: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Circle()
                    .fill(AppTheme.accentBlue.opacity(0.2))
                    .frame(width: size.width * 0.9, height: size.width * 0.9)
                    .offset(x: -size.width * 0.35, y: -size.height * 0.35)
                    .blur(radius: 10)

                RoundedRectangle(cornerRadius: 60, style: .continuous)
                    .fill(AppTheme.accentPeach.opacity(0.15))
                    .frame(width: size.width * 0.8, height: size.height * 0.6)
                    .rotationEffect(.degrees(18))
                    .offset(x: size.width * 0.25, y: -size.height * 0.15)
                    .blur(radius: 6)

                Rectangle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: size.width, height: size.height)
                    .mask(
                        LinearGradient(
                            colors: [Color.clear, Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

private struct HistorySheet: View {
    let history: [HistoryEntry]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                .ignoresSafeArea()

                BackgroundOrnament()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {

                        if history.isEmpty {
                            Text("No log yet")
                                .font(AppTypography.ui(14, weight: .medium))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(history) { entry in
                                HistoryRow(entry: entry)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Log")
                        .font(AppTypography.ui(11))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(AppTypography.body(15))
                .foregroundStyle(AppTheme.textPrimary.opacity(0.9))
                .lineSpacing(5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppSurface(cornerRadius: 16, fill: AppTheme.surface, stroke: AppTheme.strokeSoft, shadowRadius: 10, shadowY: 6)
        )
    }
}

#Preview {
    ContentView()
}
#Preview("Story Player - Start") {
    let library = ScriptLibrary.loadFromBundle()
    let saveStore = SaveStore()
    if let story = library.stories.first {
        StoryPlayerView(
            story: story,
            initialSceneId: story.startSceneId,
            saveStore: saveStore,
            onExit: {},
            onThanks: {}
        )
        .previewDevice("iPhone 17 Pro")
    } else {
        Text("No story available")
            .previewDevice("iPhone 17 Pro")
    }
}
