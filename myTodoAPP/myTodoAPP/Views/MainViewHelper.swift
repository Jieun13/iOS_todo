//
//  MainViewHelper.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct MainViewHelper {
    static func getCategoryColor(_ category: TimeCategory) -> Color {
        switch category {
        case .morning: return .red
        case .daytime: return .orange
        case .evening: return .green
        case .night: return .blue
        }
    }
    
    static func getTodayTodos(from todoStore: TodoStore) -> [TodoItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let todayTodos = todoStore.todos.filter { todo in
            let todoDate = Calendar.current.startOfDay(for: todo.createdAt)
            return todoDate >= today && todoDate < tomorrow
        }
        
        return todayTodos
    }
    
    static func getTodosForCategory(_ category: TimeCategory?, from todoStore: TodoStore) -> [TodoItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let todayTodos = todoStore.todos.filter { todo in
            let todoDate = Calendar.current.startOfDay(for: todo.createdAt)
            return todoDate >= today && todoDate < tomorrow && todo.timeCategory == category
        }
        
        return todoStore.sortTodos(todayTodos)
    }
    
    static func getTodosByType(_ type: TodoType, from todoStore: TodoStore) -> [TodoItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        let todayTodos = todoStore.todos.filter { todo in
            let todoDate = Calendar.current.startOfDay(for: todo.createdAt)
            return todoDate >= today && todoDate < tomorrow && todo.type == type
        }
        
        return todoStore.sortTodos(todayTodos)
    }
}

