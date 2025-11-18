//
//  TodoStore.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import Combine
import SwiftUI

class TodoStore: ObservableObject {
    @Published var todos: [TodoItem] = []
    
    private let todosKey = "savedTodos"
    
    init() {
        loadTodos()
    }
    
    func addTodo(_ todo: TodoItem) {
        todos.append(todo)
        saveTodos()
    }
    
    func updateTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
            saveTodos()
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        saveTodos()
    }
    
    func deleteTodoWithReminder(_ todo: TodoItem, calendarSyncService: CalendarSyncService) {
        // 미리알림이 있으면 삭제
        if todo.reminderIdentifier != nil {
            calendarSyncService.deleteReminder(for: todo)
        }
        deleteTodo(todo)
    }
    
    func toggleStatus(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            var updatedTodo = todos[index]
            // 3단계 상태 전환: 미완료 → 진행중 → 완료 → 미완료
            switch updatedTodo.status {
            case .notStarted:
                updatedTodo.status = .inProgress
            case .inProgress:
                updatedTodo.status = .completed
                updatedTodo.completedAt = Date()
            case .completed:
                updatedTodo.status = .notStarted
                updatedTodo.completedAt = nil
            }
            todos[index] = updatedTodo
            saveTodos()
        }
    }
    
    // 하위 호환성을 위한 메서드
    func toggleComplete(_ todo: TodoItem) {
        toggleStatus(todo)
    }
    
    func moveTodoToNextTimeCategory(_ todo: TodoItem, calendarSyncService: CalendarSyncService? = nil) {
        guard let currentCategory = todo.timeCategory else { return }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex < categories.count - 1 {
            var updatedTodo = todo
            let newCategory = categories[currentIndex + 1]
            
            // startTime이 있고 미리알림에서 가져온 경우 시간 제거
            if updatedTodo.startTime != nil && updatedTodo.reminderIdentifier != nil {
                updatedTodo.startTime = nil
                // 미리알림에서도 시간 제거
                if let calendarSyncService = calendarSyncService {
                    calendarSyncService.removeReminderTime(for: updatedTodo)
                }
            }
            
            updatedTodo.timeCategory = newCategory
            updateTodo(updatedTodo)
        }
    }
    
    func moveTodoToPreviousTimeCategory(_ todo: TodoItem, calendarSyncService: CalendarSyncService? = nil) {
        guard let currentCategory = todo.timeCategory else { return }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex > 0 {
            var updatedTodo = todo
            let newCategory = categories[currentIndex - 1]
            
            // startTime이 있고 미리알림에서 가져온 경우 시간 제거
            if updatedTodo.startTime != nil && updatedTodo.reminderIdentifier != nil {
                updatedTodo.startTime = nil
                // 미리알림에서도 시간 제거
                if let calendarSyncService = calendarSyncService {
                    calendarSyncService.removeReminderTime(for: updatedTodo)
                }
            }
            
            updatedTodo.timeCategory = newCategory
            updateTodo(updatedTodo)
        }
    }
    
    func moveTodoToTimeCategory(_ todo: TodoItem, timeCategory: TimeCategory) {
        var updatedTodo = todo
        updatedTodo.timeCategory = timeCategory
        updateTodo(updatedTodo)
    }
    
    func moveTodo(from source: IndexSet, to destination: Int, in timeCategory: TimeCategory) {
        let filteredTodos = todos.filter { $0.timeCategory == timeCategory }
        var sortedTodos = sortTodos(filteredTodos)
        
        sortedTodos.move(fromOffsets: source, toOffset: destination)
        
        // 순서는 sortTodos에서 처리되므로 별도 조정 불필요
        // startTime은 할 일 시작 시간이므로 순서 조정에 사용하지 않음
        saveTodos()
    }
    
    func sortTodos(_ todos: [TodoItem]) -> [TodoItem] {
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
    
    func getTodos(for timeCategory: TimeCategory, type: TodoType? = nil) -> [TodoItem] {
        var filtered = todos.filter { $0.timeCategory == timeCategory }
        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }
        return sortTodos(filtered)
    }
    
    func getTodosWithoutTimeCategory(type: TodoType? = nil) -> [TodoItem] {
        var filtered = todos.filter { $0.timeCategory == nil }
        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }
        return sortTodos(filtered)
    }
    
    func saveTodos() {
        if let encoded = try? JSONEncoder().encode(todos) {
            UserDefaults.standard.set(encoded, forKey: todosKey)
        }
    }
    
    private func loadTodos() {
        if let data = UserDefaults.standard.data(forKey: todosKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) {
            // 하위 호환성: 기존 데이터에 status가 없으면 isCompleted로 변환
            todos = decoded
        }
    }
    
    /// 아침 시작 시각 기준으로 할일을 정리합니다.
    /// 다음날 아침 시작 시각이 지났으면 완료된 할일은 삭제하고, 미완료된 할일은 다음날 아침 시간대로 미룹니다.
    func cleanupOldTodos(timeSettings: TimeSettings) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // 설정된 아침 시작 시간 계산
        let morningStartComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningStart)
        guard let morningStartHour = morningStartComponents.hour,
              let morningStartMinute = morningStartComponents.minute else {
            return
        }
        
        // 오늘 아침 시작 시각
        let todayMorningStart = calendar.date(bySettingHour: morningStartHour,
                                             minute: morningStartMinute,
                                             second: 0,
                                             of: todayStart) ?? todayStart
        
        // 내일 아침 시작 시각
        let tomorrowMorningStart = calendar.date(byAdding: .day, value: 1, to: todayMorningStart) ?? todayMorningStart
        
        // 현재 시간이 내일 아침 시작 시각을 지났는지 확인
        guard now >= tomorrowMorningStart else {
            // 아직 내일 아침 시작 시각이 지나지 않았으면 정리할 필요 없음
            return
        }
        
        // 내일 아침 시작 시각이 지났으므로 정리 시작
        // 다음날 아침 시작 시각 계산
        let dayAfterTomorrowMorningStart = calendar.date(byAdding: .day, value: 1, to: tomorrowMorningStart) ?? tomorrowMorningStart
        
        var hasChanges = false
        
        // 오늘 범위(오늘 아침 시작 ~ 내일 아침 시작) 이전의 할 일 필터링 (정리 대상)
        // startTime이 있는 경우에만 시간 범위 확인, 없으면 앱에서 생성한 항목이므로 정리 대상에서 제외
        let todosToProcess = todos.filter { todo in
            // 동기화된 항목만 시간 범위로 필터링
            let isSynced = todo.calendarEventIdentifier != nil || todo.reminderIdentifier != nil
            if isSynced, let startTime = todo.startTime {
                return startTime < tomorrowMorningStart
            }
            // 앱에서 생성한 항목은 정리하지 않음 (사용자가 직접 관리)
            return false
        }
        
        for todo in todosToProcess {
            if todo.status == .completed {
                // 완료된 할일은 삭제
                todos.removeAll { $0.id == todo.id }
                hasChanges = true
            } else {
                // 미완료된 할일은 다음날 아침 시간대로 미루기
                if let index = todos.firstIndex(where: { $0.id == todo.id }) {
                    var updatedTodo = todos[index]
                    updatedTodo.type = .mustDo
                    updatedTodo.timeCategory = .morning
                    updatedTodo.startTime = dayAfterTomorrowMorningStart
                    todos[index] = updatedTodo
                    hasChanges = true
                }
            }
        }
        
        // 현재 시간 범위 밖의 동기화된 항목 제거 (캘린더/미리알림에서 가져온 것)
        // 현재 범위: 내일 아침 시작 ~ 다음날 아침 시작
        let syncedTodosOutsideRange = todos.filter { todo in
            let isSynced = todo.calendarEventIdentifier != nil || todo.reminderIdentifier != nil
            guard isSynced, let startTime = todo.startTime else { return false }
            let isInRange = startTime >= tomorrowMorningStart && startTime < dayAfterTomorrowMorningStart
            return !isInRange
        }
        
        for todo in syncedTodosOutsideRange {
            todos.removeAll { $0.id == todo.id }
            hasChanges = true
        }
        
        if hasChanges {
            saveTodos()
        }
    }
}

