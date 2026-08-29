import Foundation

indirect enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var prettyPrinted: String {
        guard JSONSerialization.isValidJSONObject(foundationValue),
              let data = try? JSONSerialization.data(
                withJSONObject: foundationValue,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: foundationValue)
        }
        return text
    }

    private var foundationValue: Any {
        switch self {
        case .object(let object):
            return object.mapValues(\.foundationValue)
        case .array(let array):
            return array.map(\.foundationValue)
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .null:
            return NSNull()
        }
    }
}

struct TraceEvent: Codable, Equatable, Identifiable, Sendable {
    let t: String
    let role: String
    let text: String?
    let tool: String?
    let args: [String: JSONValue]?
    let result: JSONValue?

    var id: String {
        [t, role, tool ?? "", text ?? ""].joined(separator: "|")
    }
}

struct Note: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: String
    let kind: String
    let summary: String
    let body: String
    let tags: [String]
    let taskIDs: [String]
    let trace: [TraceEvent]
    let captureID: String?
    let sourceCaptureID: String?
    let routineRunID: String?
    let sourceNoteID: String?
    let transcript: String?
    let title: String?
    let url: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, summary, body, tags, trace, transcript, title, url
        case createdAt = "created_at"
        case taskIDs = "task_ids"
        case captureID = "capture_id"
        case sourceCaptureID = "source_capture_id"
        case routineRunID = "routine_run_id"
        case sourceNoteID = "source_note_id"
        case imageURL = "image_url"
    }

    init(
        id: String,
        createdAt: String,
        kind: String,
        summary: String = "",
        body: String = "",
        tags: [String] = [],
        taskIDs: [String] = [],
        trace: [TraceEvent] = [],
        captureID: String? = nil,
        sourceCaptureID: String? = nil,
        routineRunID: String? = nil,
        sourceNoteID: String? = nil,
        transcript: String? = nil,
        title: String? = nil,
        url: String? = nil,
        imageURL: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.summary = summary
        self.body = body
        self.tags = tags
        self.taskIDs = taskIDs
        self.trace = trace
        self.captureID = captureID
        self.sourceCaptureID = sourceCaptureID
        self.routineRunID = routineRunID
        self.sourceNoteID = sourceNoteID
        self.transcript = transcript
        self.title = title
        self.url = url
        self.imageURL = imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        kind = try container.decode(String.self, forKey: .kind)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        taskIDs = try container.decodeIfPresent([String].self, forKey: .taskIDs) ?? []
        trace = try container.decodeIfPresent([TraceEvent].self, forKey: .trace) ?? []
        captureID = try container.decodeIfPresent(String.self, forKey: .captureID)
        sourceCaptureID = try container.decodeIfPresent(String.self, forKey: .sourceCaptureID)
        routineRunID = try container.decodeIfPresent(String.self, forKey: .routineRunID)
        sourceNoteID = try container.decodeIfPresent(String.self, forKey: .sourceNoteID)
        transcript = try container.decodeIfPresent(String.self, forKey: .transcript)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
    }
}

struct Capture: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: String?
    let source: String?
    let deviceID: String?
    let kind: String
    let text: String?
    let url: String?
    let status: String
    let error: String?
    let noteID: String?

    enum CodingKeys: String, CodingKey {
        case id, source, kind, text, url, status, error
        case createdAt = "created_at"
        case deviceID = "device_id"
        case noteID = "note_id"
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case open
    case done
    case dropped

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }
}

struct MemexTask: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    var status: TaskStatus
    let createdAt: String
    let updatedAt: String
    let tags: [String]
    let sourceNoteID: String?

    enum CodingKeys: String, CodingKey {
        case id, title, status, tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sourceNoteID = "source_note_id"
    }

    init(
        id: String,
        title: String,
        status: TaskStatus,
        createdAt: String,
        updatedAt: String,
        tags: [String] = [],
        sourceNoteID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.sourceNoteID = sourceNoteID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        status = try container.decode(TaskStatus.self, forKey: .status)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        sourceNoteID = try container.decodeIfPresent(String.self, forKey: .sourceNoteID)
    }
}

struct TextCaptureRequest: Encodable, Sendable {
    let text: String
    let source = "ios"
}

struct PatchTaskRequest: Encodable, Sendable {
    let status: TaskStatus
}

struct HealthResponse: Decodable, Sendable {
    let ok: Bool
}

struct NotesResponse: Decodable, Sendable {
    let notes: [Note]
}

struct NoteResponse: Decodable, Sendable {
    let note: Note
}

struct CaptureResponse: Decodable, Sendable {
    let capture: Capture?
    let note: Note?
    let tasks: [MemexTask]
    let id: String?

    enum CodingKeys: String, CodingKey {
        case capture, note, tasks, id
    }

    init(
        capture: Capture? = nil,
        note: Note? = nil,
        tasks: [MemexTask] = [],
        id: String? = nil
    ) {
        self.capture = capture
        self.note = note
        self.tasks = tasks
        self.id = id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        capture = try container.decodeIfPresent(Capture.self, forKey: .capture)
        note = try container.decodeIfPresent(Note.self, forKey: .note)
        tasks = try container.decodeIfPresent([MemexTask].self, forKey: .tasks) ?? []
        id = try container.decodeIfPresent(String.self, forKey: .id)
    }
}

struct TasksResponse: Decodable, Sendable {
    let tasks: [MemexTask]
}

struct TaskResponse: Decodable, Sendable {
    let task: MemexTask
}

struct APIErrorEnvelope: Decodable, Sendable {
    struct Details: Decodable, Sendable {
        let code: String
        let message: String
    }

    let error: Details
}
