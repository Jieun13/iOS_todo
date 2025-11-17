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
        
        // 현재 시간 범위 밖의 동기화된 캘린더 이벤트 제거
        let syncedCalendarTodos = todoStore.todos.filter { $0.calendarEventIdentifier != nil }
        for todo in syncedCalendarTodos {
            if todo.createdAt < startDate || todo.createdAt >= endDate {
                todoStore.deleteTodo(todo)
            }
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            guard let eventStartDate = event.startDate else { continue }
            
            // 이벤트 시작 시간이 설정된 시간 범위 내에 있는지 엄격하게 확인
            // predicateForEvents는 겹치는 이벤트를 모두 가져오므로, 시작 시간만 확인
            if eventStartDate < startDate || eventStartDate >= endDate {
                continue
            }
            
            let timeCategory = getTimeCategory(for: event, timeSettings: timeSettings)
            
            // 이미 동기화된 이벤트인지 확인 (calendarEventIdentifier로만 확인)
            let existingTodo = todoStore.todos.first { todo in
                return todo.calendarEventIdentifier == event.eventIdentifier
            }
            
            if let existing = existingTodo {
                // 기존 항목이 있으면 업데이트 (제목, 메모, 시간대, 시간이 변경되었을 수 있음)
                var updatedTodo = existing
                updatedTodo.title = event.title
                updatedTodo.memo = event.notes
                updatedTodo.timeCategory = timeCategory
                updatedTodo.createdAt = eventStartDate
                todoStore.updateTodo(updatedTodo)
            } else {
                // 새 이벤트면 추가
                let todo = TodoItem(
                    title: event.title,
                    memo: event.notes,
                    type: .mustDo,
                    timeCategory: timeCategory,
                    status: .notStarted,
                    createdAt: eventStartDate,
                    calendarEventIdentifier: event.eventIdentifier
                )
                todoStore.addTodo(todo)
            }
        }
    }
    
    func syncReminders(to todoStore: TodoStore, timeSettings: TimeSettings) {
        // 미리알림 읽기는 fullAccess가 필요합니다
        guard hasFullAccess else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
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
        
        // 현재 시간 범위 밖의 동기화된 미리알림 제거
        let syncedReminderTodos = todoStore.todos.filter { $0.reminderIdentifier != nil && $0.calendarEventIdentifier == nil }
        for todo in syncedReminderTodos {
            if todo.createdAt < startDate || todo.createdAt >= endDate {
                todoStore.deleteTodo(todo)
            }
        }
        
        for calendarItem in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendarItem])
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else { return }
                
                for reminder in reminders {
                    // dueDateComponents를 Date로 변환
                    guard let dueDateComponents = reminder.dueDateComponents else { continue }
                    let calendar = Calendar.current
                    guard let dueDate = calendar.date(from: dueDateComponents) else { continue }
                    
                    // 미리알림의 dueDate가 설정된 시간 범위 내에 있는지 엄격하게 확인
                    if dueDate < startDate || dueDate >= endDate {
                        continue
                    }
                    
                    let timeCategory = self.getTimeCategory(for: reminder, timeSettings: timeSettings)
                    let reminderIdentifier = reminder.calendarItemIdentifier
                    
                    // 이미 동기화된 미리알림인지 확인 (reminderIdentifier로 확인)
                    let existingTodo = todoStore.todos.first { todo in
                        todo.reminderIdentifier == reminderIdentifier
                    }
                    
                    if let existing = existingTodo {
                        // 기존 할일이 있으면 업데이트 (제목, 메모, 시간대, 시간, 완료 상태)
                        DispatchQueue.main.async {
                            var updatedTodo = existing
                            updatedTodo.title = reminder.title
                            updatedTodo.memo = reminder.notes
                            updatedTodo.timeCategory = timeCategory
                            updatedTodo.createdAt = dueDate
                            
                            // 완료 상태 동기화
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
    
    func createReminder(for todo: TodoItem, timeSettings: TimeSettings) -> String? {
        guard hasFullAccess else { return nil }
        
        let calendars = eventStore.calendars(for: .reminder)
        guard let defaultCalendar = calendars.first else { return nil }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = todo.title
        reminder.notes = todo.memo
        reminder.calendar = defaultCalendar
        
        // 시간대가 있으면 해당 시간대의 종료 시간으로 설정
        if let timeCategory = todo.timeCategory {
            let calendar = Calendar.current
            let today = Date()
            let todayStart = calendar.startOfDay(for: today)
            
            let dueDate: Date
            switch timeCategory {
            case .morning:
                let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningEnd)
                dueDate = calendar.date(bySettingHour: endComponents.hour ?? 9,
                                       minute: endComponents.minute ?? 0,
                                       second: 0,
                                       of: todayStart) ?? todayStart
            case .daytime:
                let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.daytimeEnd)
                dueDate = calendar.date(bySettingHour: endComponents.hour ?? 18,
                                       minute: endComponents.minute ?? 0,
                                       second: 0,
                                       of: todayStart) ?? todayStart
            case .evening:
                let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.eveningEnd)
                dueDate = calendar.date(bySettingHour: endComponents.hour ?? 22,
                                       minute: endComponents.minute ?? 0,
                                       second: 0,
                                       of: todayStart) ?? todayStart
            case .night:
                let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
                let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.nightEnd)
                dueDate = calendar.date(bySettingHour: endComponents.hour ?? 6,
                                       minute: endComponents.minute ?? 0,
                                       second: 0,
                                       of: tomorrowStart) ?? tomorrowStart
            }
            
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        } else {
            // 시간대가 없으면 오늘 날짜로만 설정
            let calendar = Calendar.current
            let today = Date()
            reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("미리알림 생성 실패: \(error)")
            return nil
        }
    }
    
    func updateReminder(for todo: TodoItem, timeSettings: TimeSettings) {
        guard hasFullAccess, let reminderIdentifier = todo.reminderIdentifier else { return }
        
        let calendars = eventStore.calendars(for: .reminder)
        
        for calendar in calendars {
            let predicate = eventStore.predicateForReminders(in: [calendar])
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                guard let reminders = reminders else { return }
                
                if let reminder = reminders.first(where: { $0.calendarItemIdentifier == reminderIdentifier }) {
                    reminder.title = todo.title
                    reminder.notes = todo.memo
                    
                    // 시간대가 있으면 해당 시간대의 종료 시간으로 업데이트
                    if let timeCategory = todo.timeCategory {
                        let calendar = Calendar.current
                        let today = Date()
                        let todayStart = calendar.startOfDay(for: today)
                        
                        let dueDate: Date
                        switch timeCategory {
                        case .morning:
                            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningEnd)
                            dueDate = calendar.date(bySettingHour: endComponents.hour ?? 9,
                                                   minute: endComponents.minute ?? 0,
                                                   second: 0,
                                                   of: todayStart) ?? todayStart
                        case .daytime:
                            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.daytimeEnd)
                            dueDate = calendar.date(bySettingHour: endComponents.hour ?? 18,
                                                   minute: endComponents.minute ?? 0,
                                                   second: 0,
                                                   of: todayStart) ?? todayStart
                        case .evening:
                            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.eveningEnd)
                            dueDate = calendar.date(bySettingHour: endComponents.hour ?? 22,
                                                   minute: endComponents.minute ?? 0,
                                                   second: 0,
                                                   of: todayStart) ?? todayStart
                        case .night:
                            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
                            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.nightEnd)
                            dueDate = calendar.date(bySettingHour: endComponents.hour ?? 6,
                                                   minute: endComponents.minute ?? 0,
                                                   second: 0,
                                                   of: tomorrowStart) ?? tomorrowStart
                        }
                        
                        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                    } else {
                        // 시간대가 없으면 오늘 날짜로만 설정
                        let calendar = Calendar.current
                        let today = Date()
                        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: today)
                    }
                    
                    do {
                        try self.eventStore.save(reminder, commit: true)
                    } catch {
                        print("미리알림 업데이트 실패: \(error)")
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
        guard let dueDateComponents = reminder.dueDateComponents else {
            return nil
        }
        let calendar = Calendar.current
        guard let dueDate = calendar.date(from: dueDateComponents) else {
            return nil
        }
        return getTimeCategory(for: dueDate, timeSettings: timeSettings)
    }
    
    private func getTimeCategory(for date: Date, timeSettings: TimeSettings) -> TimeCategory? {
        let calendar = Calendar.current
        let dateMinute = calendar.component(.minute, from: date)
        let dateTimeInMinutes = calendar.component(.hour, from: date) * 60 + dateMinute
        
        // 설정된 시간대를 사용하여 시간대 결정
        let morningStartMinutes = calendar.component(.hour, from: timeSettings.morningStart) * 60 + calendar.component(.minute, from: timeSettings.morningStart)
        let morningEndMinutes = calendar.component(.hour, from: timeSettings.morningEnd) * 60 + calendar.component(.minute, from: timeSettings.morningEnd)
        let daytimeStartMinutes = calendar.component(.hour, from: timeSettings.daytimeStart) * 60 + calendar.component(.minute, from: timeSettings.daytimeStart)
        let daytimeEndMinutes = calendar.component(.hour, from: timeSettings.daytimeEnd) * 60 + calendar.component(.minute, from: timeSettings.daytimeEnd)
        let eveningStartMinutes = calendar.component(.hour, from: timeSettings.eveningStart) * 60 + calendar.component(.minute, from: timeSettings.eveningStart)
        let eveningEndMinutes = calendar.component(.hour, from: timeSettings.eveningEnd) * 60 + calendar.component(.minute, from: timeSettings.eveningEnd)
        let nightStartMinutes = calendar.component(.hour, from: timeSettings.nightStart) * 60 + calendar.component(.minute, from: timeSettings.nightStart)
        let nightEndMinutes = calendar.component(.hour, from: timeSettings.nightEnd) * 60 + calendar.component(.minute, from: timeSettings.nightEnd)
        
        // 시간대 범위 확인 (자정을 넘어가는 경우 처리)
        if morningStartMinutes <= morningEndMinutes {
            // 일반적인 경우 (예: 6시 ~ 9시)
            if dateTimeInMinutes >= morningStartMinutes && dateTimeInMinutes < morningEndMinutes {
                return .morning
            }
        } else {
            // 자정을 넘어가는 경우 (예: 22시 ~ 6시)
            if dateTimeInMinutes >= morningStartMinutes || dateTimeInMinutes < morningEndMinutes {
                return .morning
            }
        }
        
        if daytimeStartMinutes <= daytimeEndMinutes {
            if dateTimeInMinutes >= daytimeStartMinutes && dateTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        } else {
            if dateTimeInMinutes >= daytimeStartMinutes || dateTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        }
        
        if eveningStartMinutes <= eveningEndMinutes {
            if dateTimeInMinutes >= eveningStartMinutes && dateTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        } else {
            if dateTimeInMinutes >= eveningStartMinutes || dateTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        }
        
        if nightStartMinutes <= nightEndMinutes {
            if dateTimeInMinutes >= nightStartMinutes && dateTimeInMinutes < nightEndMinutes {
                return .night
            }
        } else {
            if dateTimeInMinutes >= nightStartMinutes || dateTimeInMinutes < nightEndMinutes {
                return .night
            }
        }
        
        // 기본값 (어떤 시간대에도 해당하지 않는 경우)
        return .daytime
    }
}

