//
//  TodoItem.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation

enum TimeCategory: String, Codable, CaseIterable {
    case morning = "아침"
    case daytime = "일과 중"
    case evening = "귀가 후"
    case night = "자기 전"
    
    var color: String {
        switch self {
        case .morning: return "red"
        case .daytime: return "orange"
        case .evening: return "green"
        case .night: return "blue"
        }
    }
}

enum TodoType: String, Codable {
    case mustDo = "해야 할 일"
    case wantToDo = "하고 싶은 일"
}

enum TodoStatus: String, Codable {
    case notStarted = "미완료"
    case inProgress = "진행중"
    case completed = "완료"
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var memo: String?
    var type: TodoType
    var timeCategory: TimeCategory?
    var status: TodoStatus
    var startTime: Date? // 할 일 시작 시간 (캘린더/미리알림에서 가져온 경우에만 설정)
    var completedAt: Date?
    var reminderIdentifier: String? // 미리알림과의 연결을 위한 식별자
    var calendarEventIdentifier: String? // 캘린더 이벤트와의 연결을 위한 식별자
    
    // 하위 호환성을 위한 computed property
    var isCompleted: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .notStarted }
    }
    
    // 하위 호환성: createdAt을 startTime으로 마이그레이션
    private enum CodingKeys: String, CodingKey {
        case id, title, memo, type, timeCategory, status, startTime, completedAt, reminderIdentifier, calendarEventIdentifier
        case createdAt // 하위 호환성을 위해 유지
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        type = try container.decode(TodoType.self, forKey: .type)
        timeCategory = try container.decodeIfPresent(TimeCategory.self, forKey: .timeCategory)
        status = try container.decode(TodoStatus.self, forKey: .status)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        reminderIdentifier = try container.decodeIfPresent(String.self, forKey: .reminderIdentifier)
        calendarEventIdentifier = try container.decodeIfPresent(String.self, forKey: .calendarEventIdentifier)
        
        // 하위 호환성: createdAt이 있으면 startTime으로 변환, 없으면 nil
        if let createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            startTime = createdAt
        } else {
            startTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(timeCategory, forKey: .timeCategory)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(startTime, forKey: .startTime)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(reminderIdentifier, forKey: .reminderIdentifier)
        try container.encodeIfPresent(calendarEventIdentifier, forKey: .calendarEventIdentifier)
    }
    
    init(id: UUID = UUID(), title: String, memo: String? = nil, type: TodoType, timeCategory: TimeCategory? = nil, status: TodoStatus = .notStarted, startTime: Date? = nil, completedAt: Date? = nil, reminderIdentifier: String? = nil, calendarEventIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.memo = memo
        self.type = type
        self.timeCategory = timeCategory
        self.status = status
        self.startTime = startTime
        self.completedAt = completedAt
        self.reminderIdentifier = reminderIdentifier
        self.calendarEventIdentifier = calendarEventIdentifier
    }
}

