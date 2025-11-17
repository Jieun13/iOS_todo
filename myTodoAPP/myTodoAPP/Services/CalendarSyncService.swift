//
//  CalendarSyncService.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import EventKit
import Combine

class CalendarSyncService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasFullAccess: Bool = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAccess() async -> Bool {
        // 기존 방식 사용 (모든 iOS 버전 호환)
        do {
            let eventStatus = try await eventStore.requestAccess(to: .event)
            let reminderStatus = try await eventStore.requestAccess(to: .reminder)
            await MainActor.run {
                hasFullAccess = eventStatus && reminderStatus
            }
            return eventStatus && reminderStatus
        } catch {
            await MainActor.run {
                hasFullAccess = false
            }
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        // 기존 방식 사용 (모든 iOS 버전 호환)
        let eventStatus = EKEventStore.authorizationStatus(for: .event)
        let reminderStatus = EKEventStore.authorizationStatus(for: .reminder)
        hasFullAccess = (eventStatus == .authorized) && (reminderStatus == .authorized)
    }
    
    var isAuthorized: Bool {
        return hasFullAccess
    }
    
    func syncCalendarEvents(to todoStore: TodoStore, timeSettings: TimeSettings) {
        // 캘린더 이벤트 읽기는 fullAccess가 필요합니다
        guard hasFullAccess else { return }
        
        let calendars = eventStore.calendars(for: .event)
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            // 오늘 날짜인지 확인
            guard let eventStartDate = event.startDate else { continue }
            let eventDate = Calendar.current.startOfDay(for: eventStartDate)
            let today = Calendar.current.startOfDay(for: Date())
            
            guard eventDate == today else { continue }
            
            let timeCategory = getTimeCategory(for: event, timeSettings: timeSettings)
            
            // 이미 동기화된 이벤트인지 확인 (제목과 날짜로 확인)
            let existingTodo = todoStore.todos.first { todo in
                todo.title == event.title && 
                Calendar.current.startOfDay(for: todo.createdAt) == today
            }
            
            if existingTodo == nil {
                let todo = TodoItem(
                    title: event.title,
                    memo: event.notes,
                    type: .mustDo,
                    timeCategory: timeCategory,
                    status: .notStarted,
                    createdAt: eventStartDate
                )
                todoStore.addTodo(todo)
            }
        }
    }
    
    func syncReminders(to todoStore: TodoStore, timeSettings: TimeSettings) {
        // 미리알림 읽기는 fullAccess가 필요합니다
        guard hasFullAccess else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
        let today = Calendar.current.startOfDay(for: Date())
        
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else { return }
                
                for reminder in reminders {
                    // 오늘 날짜인지 확인
                    guard let dueDate = reminder.dueDateComponents?.date else { continue }
                    let reminderDate = Calendar.current.startOfDay(for: dueDate)
                    
                    guard reminderDate == today else { continue }
                    
                    let timeCategory = self.getTimeCategory(for: reminder, timeSettings: timeSettings)
                    let reminderIdentifier = reminder.calendarItemIdentifier
                    
                    // 이미 동기화된 미리알림인지 확인 (reminderIdentifier로 확인)
                    let existingTodo = todoStore.todos.first { todo in
                        todo.reminderIdentifier == reminderIdentifier
                    }
                    
                    if let existing = existingTodo {
                        // 기존 할일이 있으면 미리알림의 완료 상태와 동기화
                        DispatchQueue.main.async {
                            var updatedTodo = existing
                            if reminder.isCompleted && updatedTodo.status != .completed {
                                updatedTodo.status = .completed
                                updatedTodo.completedAt = Date()
                            } else if !reminder.isCompleted && updatedTodo.status == .completed {
                                updatedTodo.status = .notStarted
                                updatedTodo.completedAt = nil
                            }
                            todoStore.updateTodo(updatedTodo)
                        }
                    } else if !reminder.isCompleted {
                        // 새 미리알림이면 할일로 추가
                        let todo = TodoItem(
                            title: reminder.title,
                            memo: reminder.notes,
                            type: .mustDo,
                            timeCategory: timeCategory,
                            status: .notStarted,
                            createdAt: dueDate,
                            reminderIdentifier: reminderIdentifier
                        )
                        DispatchQueue.main.async {
                            todoStore.addTodo(todo)
                        }
                    }
                }
            }
        }
    }
    
    func completeReminder(for todo: TodoItem) {
        guard hasFullAccess, let reminderIdentifier = todo.reminderIdentifier else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
        
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else { return }
                
                if let reminder = reminders.first(where: { $0.calendarItemIdentifier == reminderIdentifier }) {
                    do {
                        reminder.isCompleted = true
                        reminder.completionDate = Date()
                        try self.eventStore.save(reminder, commit: true)
                    } catch {
                        print("미리알림 완료 처리 실패: \(error)")
                    }
                }
            }
        }
    }
    
    private func getTimeCategory(for event: EKEvent, timeSettings: TimeSettings) -> TimeCategory? {
        guard let startDate = event.startDate else { return nil }
        return getTimeCategory(for: startDate, timeSettings: timeSettings)
    }
    
    private func getTimeCategory(for reminder: EKReminder, timeSettings: TimeSettings) -> TimeCategory? {
        guard let dueDate = reminder.dueDateComponents?.date else {
            return nil
        }
        return getTimeCategory(for: dueDate, timeSettings: timeSettings)
    }
    
    private func getTimeCategory(for date: Date, timeSettings: TimeSettings) -> TimeCategory? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // 시간대별로 분류
        if hour >= 6 && hour < 9 {
            return .morning
        } else if hour >= 9 && hour < 18 {
            return .daytime
        } else if hour >= 18 && hour < 22 {
            return .evening
        } else {
            return .night
        }
    }
}

