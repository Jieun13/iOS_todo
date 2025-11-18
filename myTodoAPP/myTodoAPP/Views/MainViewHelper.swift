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
    
    // 현재 시간 범위 계산 (아침 시작 시각 기준으로 하루 범위 정의)
    // 하루 = 아침 시작 시각 ~ 다음날 아침 시작 시각
    static func getCurrentTimeRange(timeSettings: TimeSettings) -> (startDate: Date, endDate: Date) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // 설정된 아침 시작 시간 계산
        let morningStartComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningStart)
        
        guard let morningStartHour = morningStartComponents.hour,
              let morningStartMinute = morningStartComponents.minute else {
            // 기본값 반환
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return (todayStart, tomorrow)
        }
        
        // 오늘 아침 시작 시각
        let todayMorningStart = calendar.date(bySettingHour: morningStartHour,
                                             minute: morningStartMinute,
                                             second: 0,
                                             of: todayStart) ?? todayStart
        
        // 내일 아침 시작 시각
        let tomorrowMorningStart = calendar.date(byAdding: .day, value: 1, to: todayMorningStart) ?? todayMorningStart
        
        let startDate: Date
        let endDate: Date
        
        // 현재 시간이 어느 범위에 속하는지 확인
        if now >= todayMorningStart && now < tomorrowMorningStart {
            // 오늘 범위: 오늘 아침 시작 ~ 내일 아침 시작
            startDate = todayMorningStart
            endDate = tomorrowMorningStart
        } else {
            // 새벽 시간대 (0시 ~ 아침 시작 전): 어제 범위
            let yesterdayMorningStart = calendar.date(byAdding: .day, value: -1, to: todayMorningStart) ?? todayMorningStart
            startDate = yesterdayMorningStart
            endDate = todayMorningStart
        }
        
        return (startDate, endDate)
    }
    
    static func getTodayTodos(from todoStore: TodoStore, timeSettings: TimeSettings) -> [TodoItem] {
        let (startDate, endDate) = getCurrentTimeRange(timeSettings: timeSettings)
        
        let todayTodos = todoStore.todos.filter { todo in
            // startTime이 있으면 시간 범위로 필터링, 없으면 앱에서 생성한 항목이므로 포함
            if let startTime = todo.startTime {
                return startTime >= startDate && startTime < endDate
            } else {
                // 앱에서 생성한 항목은 항상 포함
                return true
            }
        }
        
        return todayTodos
    }
    
    static func getTodosForCategory(_ category: TimeCategory?, from todoStore: TodoStore, timeSettings: TimeSettings) -> [TodoItem] {
        let (startDate, endDate) = getCurrentTimeRange(timeSettings: timeSettings)
        
        let todayTodos = todoStore.todos.filter { todo in
            let timeInRange: Bool
            if let startTime = todo.startTime {
                timeInRange = startTime >= startDate && startTime < endDate
            } else {
                // 앱에서 생성한 항목은 항상 포함
                timeInRange = true
            }
            return timeInRange && todo.timeCategory == category
        }
        
        return todoStore.sortTodos(todayTodos)
    }
    
    static func getTodosByType(_ type: TodoType, from todoStore: TodoStore, timeSettings: TimeSettings) -> [TodoItem] {
        let (startDate, endDate) = getCurrentTimeRange(timeSettings: timeSettings)
        
        let todayTodos = todoStore.todos.filter { todo in
            let timeInRange: Bool
            if let startTime = todo.startTime {
                timeInRange = startTime >= startDate && startTime < endDate
            } else {
                // 앱에서 생성한 항목은 항상 포함
                timeInRange = true
            }
            return timeInRange && todo.type == type
        }
        
        return todoStore.sortTodos(todayTodos)
    }
}

