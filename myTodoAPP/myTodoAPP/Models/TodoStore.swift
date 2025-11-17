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
    
    func moveTodoToNextTimeCategory(_ todo: TodoItem) {
        guard let currentCategory = todo.timeCategory else { return }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex < categories.count - 1 {
            var updatedTodo = todo
            updatedTodo.timeCategory = categories[currentIndex + 1]
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
        
        // 순서를 저장하기 위해 order 속성을 사용하거나, createdAt을 조정
        // 여기서는 간단하게 createdAt을 조정하는 방식 사용
        for (index, todo) in sortedTodos.enumerated() {
            if let originalIndex = todos.firstIndex(where: { $0.id == todo.id }) {
                var updatedTodo = todos[originalIndex]
                // 순서를 반영하기 위해 createdAt을 미세 조정
                let baseDate = todo.createdAt
                let adjustedDate = Calendar.current.date(byAdding: .second, value: index, to: baseDate) ?? baseDate
                updatedTodo.createdAt = adjustedDate
                todos[originalIndex] = updatedTodo
            }
        }
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
            
            // 3. 최근 추가한 것이 아래로 (createdAt이 큰 것이 아래)
            return todo1.createdAt > todo2.createdAt
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
        // 로드 후 전날 할일 정리
        cleanupOldTodos()
    }
    
    /// 매일 새벽 5시 기준으로 전날 할일을 정리합니다.
    /// 완료된 할일은 삭제하고, 미완료된 할일은 "해야 할 일" + "시간대 미지정"으로 변경합니다.
    func cleanupOldTodos() {
        let calendar = Calendar.current
        let now = Date()
        
        // 오늘 새벽 5시 계산
        let today5AM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: now) ?? now
        
        // 기준 날짜: 현재 시간이 오늘 새벽 5시 이전이면 어제, 이후면 오늘
        let referenceDate = now < today5AM ? calendar.date(byAdding: .day, value: -1, to: now) ?? now : now
        let reference5AM = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: referenceDate) ?? referenceDate
        
        var hasChanges = false
        
        // 전날 할일 필터링 (createdAt이 reference5AM 이전인 것들)
        let oldTodos = todos.filter { todo in
            todo.createdAt < reference5AM
        }
        
        for oldTodo in oldTodos {
            if oldTodo.status == .completed {
                // 완료된 할일은 삭제
                todos.removeAll { $0.id == oldTodo.id }
                hasChanges = true
            } else {
                // 미완료된 할일은 "해야 할 일" + "시간대 미지정"으로 변경하고 오늘 날짜로 업데이트
                if let index = todos.firstIndex(where: { $0.id == oldTodo.id }) {
                    var updatedTodo = todos[index]
                    updatedTodo.type = .mustDo
                    updatedTodo.timeCategory = nil
                    updatedTodo.createdAt = now // 오늘 날짜로 업데이트
                    todos[index] = updatedTodo
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            saveTodos()
        }
    }
}

