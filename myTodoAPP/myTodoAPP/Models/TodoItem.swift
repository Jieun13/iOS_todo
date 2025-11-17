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

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var memo: String?
    var type: TodoType
    var timeCategory: TimeCategory?
    var status: TodoStatus
    var createdAt: Date
    var completedAt: Date?
    var reminderIdentifier: String? // 미리알림과의 연결을 위한 식별자
    var calendarEventIdentifier: String? // 캘린더 이벤트와의 연결을 위한 식별자
    
    // 하위 호환성을 위한 computed property
    var isCompleted: Bool {
        get { status == .completed }
        set { status = newValue ? .completed : .notStarted }
    }
    
    init(id: UUID = UUID(), title: String, memo: String? = nil, type: TodoType, timeCategory: TimeCategory? = nil, status: TodoStatus = .notStarted, createdAt: Date = Date(), completedAt: Date? = nil, reminderIdentifier: String? = nil, calendarEventIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.memo = memo
        self.type = type
        self.timeCategory = timeCategory
        self.status = status
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderIdentifier = reminderIdentifier
        self.calendarEventIdentifier = calendarEventIdentifier
    }
}

