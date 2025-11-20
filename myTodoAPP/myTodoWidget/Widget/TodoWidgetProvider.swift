//
//  TodoWidgetProvider.swift
//  myTodoAPP
//
//  Created on 11/19/25.
//

import WidgetKit
import SwiftUI

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let currentTimeCategory: TimeCategory
    let todos: [TodoItem]
    let timeSettings: TimeSettings
    let timeRemaining: TimeInterval // 초 단위
    let remainingTodosCount: Int
}

struct TodoWidgetProvider: TimelineProvider {
    typealias Entry = TodoWidgetEntry
    
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(
            date: Date(),
            currentTimeCategory: .morning,
            todos: [
                TodoItem(
                    title: "샘플 할 일 1",
                    type: .mustDo,
                    timeCategory: .morning,
                    status: .notStarted
                ),
                TodoItem(
                    title: "샘플 할 일 2",
                    type: .mustDo,
                    timeCategory: .morning,
                    status: .inProgress
                )
            ],
            timeSettings: TimeSettings.defaultSettings,
            timeRemaining: 7200, // 2시간
            remainingTodosCount: 2
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodoWidgetEntry) -> Void) {
        let entry = loadWidgetData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoWidgetEntry>) -> Void) {
        let entry = loadWidgetData()
        
        // 다음 업데이트 시간 계산 (15분마다 업데이트)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    private func loadWidgetData() -> TodoWidgetEntry {
        // App Group을 사용하여 메인 앱과 데이터 공유
        let appGroupIdentifier = "group.com.jieun.Jiny-TODO"
        let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)
        
        let todosKey = "savedTodos"
        let settingsKey = "timeSettings"
        
        var todos: [TodoItem] = []
        var timeSettings = TimeSettings.defaultSettings
        
        // 할 일 로드 (App Group에서 먼저 시도)
        if let data = sharedDefaults?.data(forKey: todosKey) ?? UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = decoded
        }
        
        // 시간 설정 로드 (App Group에서 먼저 시도)
        if let data = sharedDefaults?.data(forKey: settingsKey) ?? UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(TimeSettings.self, from: data) {
            timeSettings = decoded
        }
        
        // 현재 시간대 계산
        let currentTimeCategory = timeSettings.getCurrentTimeCategory()
        
        // 현재 시간대의 할 일 필터링 (메인 뷰와 동일한 로직)
        let (startDate, endDate) = MainViewHelper.getCurrentTimeRange(timeSettings: timeSettings)
        let filteredTodos = todos.filter { todo in
            // 시간 범위 체크
            let timeInRange: Bool
            if let startTime = todo.startTime {
                timeInRange = startTime >= startDate && startTime < endDate
            } else {
                // 앱에서 생성한 항목은 항상 포함
                timeInRange = true
            }
            // 현재 시간대에 속하는 할 일만
            return timeInRange && todo.timeCategory == currentTimeCategory
        }
        
        // 정렬 (진행중 > 미완료 > 완료 순서)
        let sortedTodos = sortTodos(filteredTodos)
        
        // 최대 5개만 표시 (위젯 크기에 따라 조정)
        let displayTodos = Array(sortedTodos.prefix(5))
        
        // 남은 할 일 개수 계산 (메인 뷰의 getIncompleteCount()와 동일한 로직)
        // filteredTodos에서 완료되지 않은 것만 필터링
        let remainingTodos = filteredTodos.filter { todo in
            todo.status != .completed
        }
        
        // 현재 시간대 종료 시간 계산
        let timeCategoryEndDate = getTimeCategoryEndDate(category: currentTimeCategory, timeSettings: timeSettings)
        
        // 남은 시간 계산
        let now = Date()
        let timeRemaining = max(0, timeCategoryEndDate.timeIntervalSince(now))
        
        return TodoWidgetEntry(
            date: now,
            currentTimeCategory: currentTimeCategory,
            todos: displayTodos,
            timeSettings: timeSettings,
            timeRemaining: timeRemaining,
            remainingTodosCount: remainingTodos.count
        )
    }
    
    // 할 일 정렬 로직 (TodoStore의 sortTodos와 동일)
    private func sortTodos(_ todos: [TodoItem]) -> [TodoItem] {
        return todos.sorted { todo1, todo2 in
            // 1. 상태 순서: 진행중 > 미완료 > 완료
            let statusOrder: [TodoStatus] = [.inProgress, .notStarted, .completed]
            let status1 = statusOrder.firstIndex(of: todo1.status) ?? Int.max
            let status2 = statusOrder.firstIndex(of: todo2.status) ?? Int.max
            if status1 != status2 {
                return status1 < status2
            }
            
            // 2. 타입 순서: 해야할일 > 하고싶은일
            if todo1.type != todo2.type {
                return todo1.type == .mustDo
            }
            
            // 3. startTime이 있는 항목은 시간 순으로 정렬
            if let time1 = todo1.startTime, let time2 = todo2.startTime {
                return time1 < time2
            } else if todo1.startTime != nil {
                // todo1만 시간 정보가 있으면 위로
                return true
            } else if todo2.startTime != nil {
                // todo2만 시간 정보가 있으면 위로
                return false
            } else {
                // 둘 다 시간 정보가 없으면 ID 순서로 정렬 (안정적인 정렬)
                return todo1.id.uuidString < todo2.id.uuidString
            }
        }
    }
    
    // 시간대별 종료 시간 계산
    private func getTimeCategoryEndDate(category: TimeCategory, timeSettings: TimeSettings) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        let endDate: Date
        
        switch category {
        case .morning:
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningEnd)
            if let hour = endComponents.hour, let minute = endComponents.minute {
                var candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? now
                if candidate <= now {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? now
                }
                endDate = candidate
            } else {
                endDate = now
            }
            
        case .daytime:
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.daytimeEnd)
            if let hour = endComponents.hour, let minute = endComponents.minute {
                var candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? now
                if candidate <= now {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? now
                }
                endDate = candidate
            } else {
                endDate = now
            }
            
        case .evening:
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.eveningEnd)
            if let hour = endComponents.hour, let minute = endComponents.minute {
                var candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? now
                if candidate <= now {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? now
                }
                endDate = candidate
            } else {
                endDate = now
            }
            
        case .night:
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.nightEnd)
            if let hour = endComponents.hour, let minute = endComponents.minute {
                var candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: todayStart) ?? now
                if candidate <= now {
                    candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? now
                }
                endDate = candidate
            } else {
                endDate = now
            }
        }
        
        return endDate
    }
}

