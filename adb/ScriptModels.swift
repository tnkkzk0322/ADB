import Foundation

struct ScriptLibrary: Codable {
    let stories: [Story]

    static func loadFromBundle() -> ScriptLibrary {
        guard let url = Bundle.main.url(forResource: "ScriptData", withExtension: "json") else {
            return .fallback
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ScriptLibrary.self, from: data)
        } catch {
            return .fallback
        }
    }

    static let fallback = ScriptLibrary(
        stories: [
            Story(
                id: "fallback",
                title: "Fallback Story",
                description: "Fallback scene shown when the script fails to load.",
                startSceneId: "fallback_scene",
                scenes: [
                    ScriptScene(
                        id: "fallback_scene",
                        title: "Missing Script",
                        lines: [
                            ScriptLine(id: "fallback_line", speaker: "System", text: "ScriptData.json was not found.")
                        ],
                        choices: [
                            Choice(id: "fallback_choice", text: "Back to start", nextSceneId: "fallback_scene")
                        ]
                    )
                ]
            )
        ]
    )
}

struct Story: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let startSceneId: String
    let scenes: [ScriptScene]

    func scene(id: String) -> ScriptScene? {
        scenes.first { $0.id == id }
    }

    var fallbackScene: ScriptScene {
        ScriptScene(
            id: "missing",
            title: "Missing Scene",
            lines: [
                ScriptLine(id: "missing_line", speaker: "System", text: "The requested scene could not be found.")
            ],
            choices: [
                Choice(id: "missing_choice", text: "Back to start", nextSceneId: startSceneId)
            ]
        )
    }
}

struct ScriptScene: Identifiable, Codable {
    let id: String
    let title: String
    let backgroundImageName: String
    let characters: [SceneCharacter]
    let lines: [ScriptLine]
    let choices: [Choice]

    init(
        id: String,
        title: String,
        backgroundImageName: String = "",
        characters: [SceneCharacter] = [],
        lines: [ScriptLine],
        choices: [Choice]
    ) {
        self.id = id
        self.title = title
        self.backgroundImageName = backgroundImageName
        self.characters = characters
        self.lines = lines
        self.choices = choices
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case backgroundImageName
        case characters
        case lines
        case choices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        backgroundImageName = (try? container.decode(String.self, forKey: .backgroundImageName)) ?? ""
        characters = (try? container.decode([SceneCharacter].self, forKey: .characters)) ?? []
        lines = try container.decode([ScriptLine].self, forKey: .lines)
        choices = try container.decode([Choice].self, forKey: .choices)
    }
}

struct SceneCharacter: Identifiable, Codable {
    let id: String
    let name: String
    let imageName: String
}

enum ScriptLineKind: String, Codable {
    case dialogue
    case narration
}

struct ScriptLine: Identifiable, Codable {
    let id: String
    let speaker: String
    let text: String
    let kind: ScriptLineKind

    init(id: String, speaker: String, text: String, kind: ScriptLineKind = .dialogue) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case speaker
        case text
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        speaker = (try? container.decode(String.self, forKey: .speaker)) ?? ""
        text = try container.decode(String.self, forKey: .text)
        kind = (try? container.decode(ScriptLineKind.self, forKey: .kind)) ?? .dialogue
    }
}

struct Choice: Identifiable, Codable {
    let id: String
    let text: String
    let nextSceneId: String
    let speaker: String

    init(id: String, text: String, nextSceneId: String, speaker: String = "") {
        self.id = id
        self.text = text
        self.nextSceneId = nextSceneId
        self.speaker = speaker
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case nextSceneId
        case speaker
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        nextSceneId = try container.decode(String.self, forKey: .nextSceneId)
        speaker = (try? container.decode(String.self, forKey: .speaker)) ?? ""
    }
}

struct SaveStore {
    private let key = "adb.savepoints"

    func loadSceneId(for storyId: String) -> String? {
        let dictionary = UserDefaults.standard.dictionary(forKey: key) as? [String: String]
        return dictionary?[storyId]
    }

    func saveSceneId(_ sceneId: String, for storyId: String) {
        var dictionary = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        dictionary[storyId] = sceneId
        UserDefaults.standard.set(dictionary, forKey: key)
    }
}
