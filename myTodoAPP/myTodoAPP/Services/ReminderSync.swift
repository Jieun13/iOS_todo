//
//  ReminderSync.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import EventKit

struct ReminderSync {
    let eventStore: EKEventStore
    
    func syncReminders(to todoStore: TodoStore, timeSettings: TimeSettings) {
        // 미리알림 읽기는 fullAccess가 필요합니다
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized else { return }
        
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
        
        // 하루 범위: 현재 시간에 따라 동적으로 설정
        // 새벽 시간대면 어제 아침 시작 ~ 오늘 아침 시작 전까지
        // 일반 시간대면 오늘 아침 시작 ~ 내일 아침 시작 전까지
        let dayRangeStart: Date
        let dayRangeEnd: Date
        
        if now >= todayMorningStart && now < tomorrowMorningStart {
            // 일반 시간대: 오늘 아침 시작 ~ 내일 아침 시작 전까지
            dayRangeStart = todayMorningStart
            dayRangeEnd = tomorrowMorningStart
        } else {
            // 새벽 시간대: 어제 아침 시작 ~ 오늘 아침 시작 전까지
            let yesterdayMorningStart = calendar.date(byAdding: .day, value: -1, to: todayMorningStart) ?? todayMorningStart
            dayRangeStart = yesterdayMorningStart
            dayRangeEnd = todayMorningStart
        }
        
        // 앱에서 생성한 할 일의 reminderIdentifier 수집 (나중에 미리알림에서 삭제되었는지 확인)
        let appCreatedReminderIdentifiers = Set(todoStore.todos
            .filter { $0.reminderIdentifier != nil && $0.startTime == nil }
            .compactMap { $0.reminderIdentifier })
        
        // 이미 앱에 있는 미리알림의 identifier 수집 (식별자로 직접 업데이트하기 위해)
        let existingReminderIdentifiers = Set(todoStore.todos
            .filter { $0.reminderIdentifier != nil && $0.startTime != nil }
            .compactMap { $0.reminderIdentifier })
        
        let dispatchGroup = DispatchGroup()
        var foundReminderIdentifiers = Set<String>()
        let foundReminderIdentifiersQueue = DispatchQueue(label: "foundReminderIdentifiers")
        
        for calendarItem in calendars {
            dispatchGroup.enter()
            let predicate = eventStore.predicateForReminders(in: [calendarItem])
            
            eventStore.fetchReminders(matching: predicate) { reminders in
                defer { dispatchGroup.leave() }
                guard let reminders = reminders else { return }
                
                for reminder in reminders {
                    let reminderIdentifier = reminder.calendarItemIdentifier
                    _ = foundReminderIdentifiersQueue.sync {
                        foundReminderIdentifiers.insert(reminderIdentifier)
                    }
                    
                    // 이미 동기화된 미리알림인지 확인 (reminderIdentifier로 확인)
                    let existingTodo = todoStore.todos.first { todo in
                        todo.reminderIdentifier == reminderIdentifier
                    }
                    
                    // dueDateComponents를 Date로 변환
                    let dueDateComponents = reminder.dueDateComponents
                    let calendar = Calendar.current
                    let dueDate = dueDateComponents != nil ? calendar.date(from: dueDateComponents!) : nil
                    
                    // 날짜만 있는지 확인 (시간 정보가 없는 경우)
                    let hasOnlyDate = dueDateComponents != nil && dueDateComponents!.hour == nil && dueDateComponents!.minute == nil
                    
                    // 앱에서 생성한 미리알림(시간이 없는 경우) 처리
                    if let existing = existingTodo, existing.startTime == nil {
                        // 앱에서 생성한 미리알림은 제목과 메모만 업데이트
                        DispatchQueue.main.async {
                            var updatedTodo = existing
                            updatedTodo.title = reminder.title
                            updatedTodo.memo = reminder.notes
                            
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
                        continue
                    }
                    
                    // 시간이 없는 새 미리알림은 추가하지 않음
                    guard let dueDate = dueDate else { continue }
                    
                    // 앞뒤 2일치 범위 계산
                    let extendedRangeStart = calendar.date(byAdding: .day, value: -2, to: dayRangeStart) ?? dayRangeStart
                    let extendedRangeEnd = calendar.date(byAdding: .day, value: 2, to: dayRangeEnd) ?? dayRangeEnd
                    
                    // 하루 범위 내에 있는지 확인 (필터링용)
                    // 날짜만 있는 경우: dayRangeStart의 날짜부터 dayRangeEnd의 날짜 전날까지 포함
                    let isInDayRange: Bool
                    if hasOnlyDate {
                        let dueDateOnly = calendar.startOfDay(for: dueDate)
                        let dayRangeStartOnly = calendar.startOfDay(for: dayRangeStart)
                        let dayRangeEndOnly = calendar.startOfDay(for: dayRangeEnd)
                        // dayRangeStart의 날짜부터 dayRangeEnd의 날짜 전날까지
                        isInDayRange = dueDateOnly >= dayRangeStartOnly && dueDateOnly < dayRangeEndOnly
                    } else {
                        isInDayRange = dueDate >= dayRangeStart && dueDate < dayRangeEnd
                    }
                    
                    if let existing = existingTodo {
                        // 이미 앱에 있는 미리알림은 범위와 관계없이 업데이트
                        let timeCategory = TimeCategoryHelper.getTimeCategory(for: reminder, timeSettings: timeSettings)
                        DispatchQueue.main.async {
                            var updatedTodo = existing
                            updatedTodo.title = reminder.title
                            updatedTodo.memo = reminder.notes
                            updatedTodo.timeCategory = timeCategory
                            updatedTodo.startTime = dueDate
                            
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
                    } else if !reminder.isCompleted && isInDayRange {
                        // 새 미리알림이면 하루 범위 내에 있는 경우에만 추가
                        let timeCategory = TimeCategoryHelper.getTimeCategory(for: reminder, timeSettings: timeSettings)
                        let todo = TodoItem(
                            title: reminder.title,
                            memo: reminder.notes,
                            type: .mustDo,
                            timeCategory: timeCategory,
                            status: .notStarted,
                            startTime: dueDate,
                            reminderIdentifier: reminderIdentifier
                        )
                        DispatchQueue.main.async {
                            todoStore.addTodo(todo)
                        }
                    }
                }
            }
        }
        
        // 모든 캘린더 처리가 끝난 후 처리
        dispatchGroup.notify(queue: .main) {
            // 미리알림에서 삭제된 앱에서 생성한 할 일 제거
            let deletedReminderIdentifiers = appCreatedReminderIdentifiers.subtracting(foundReminderIdentifiers)
            for identifier in deletedReminderIdentifiers {
                // 식별자로 직접 접근해서 확인
                if eventStore.calendarItem(withIdentifier: identifier) == nil {
                    // 미리알림이 삭제된 경우
                    if let todo = todoStore.todos.first(where: { $0.reminderIdentifier == identifier && $0.startTime == nil }) {
                        todoStore.deleteTodo(todo)
                    }
                }
            }
            
            // 이미 앱에 있는 미리알림 중 하루 범위 밖으로 이동한 것들은 식별자로 직접 접근해서 확인
            for identifier in existingReminderIdentifiers {
                if foundReminderIdentifiers.contains(identifier) {
                    continue // 이미 처리됨
                }
                
                // 식별자로 직접 접근
                guard let calendarItem = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
                    // 미리알림이 삭제된 경우
                    if let todo = todoStore.todos.first(where: { $0.reminderIdentifier == identifier && $0.startTime != nil }) {
                        todoStore.deleteTodo(todo)
                    }
                    continue
                }
                
                // dueDateComponents를 Date로 변환
                guard let dueDateComponents = calendarItem.dueDateComponents else { continue }
                let calendar = Calendar.current
                guard let dueDate = calendar.date(from: dueDateComponents) else { continue }
                
                // 하루 범위 밖으로 이동한 경우 앱에서 제거
                if dueDate < dayRangeStart || dueDate >= dayRangeEnd {
                    if let todo = todoStore.todos.first(where: { $0.reminderIdentifier == identifier && $0.startTime != nil }) {
                        todoStore.deleteTodo(todo)
                    }
                }
            }
        }
    }
}

