//
//  CalendarEventSync.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import EventKit

struct CalendarEventSync {
    let eventStore: EKEventStore
    
    func syncCalendarEvents(to todoStore: TodoStore, timeSettings: TimeSettings) {
        // 캘린더 이벤트 읽기는 fullAccess가 필요합니다
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { return }
        
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
        
        // 이미 앱에 있는 캘린더 이벤트의 identifier 수집 (식별자로 직접 업데이트하기 위해)
        let existingCalendarEventIdentifiers = Set(todoStore.todos
            .filter { $0.calendarEventIdentifier != nil }
            .compactMap { $0.calendarEventIdentifier })
        
        // 앞뒤 2일치 포함해서 가져오기 (필터링은 나중에)
        let fetchStartDate = calendar.date(byAdding: .day, value: -2, to: dayRangeStart) ?? dayRangeStart
        let fetchEndDate = calendar.date(byAdding: .day, value: 2, to: dayRangeEnd) ?? dayRangeEnd
        
        let predicate = eventStore.predicateForEvents(withStart: fetchStartDate, end: fetchEndDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        var foundEventIdentifiers = Set<String>()
        
        // 가져온 이벤트 처리 (하루 범위 내에 있는 것만 추가, 기존 항목은 범위와 관계없이 업데이트)
        for event in events {
            guard let eventStartDate = event.startDate else { continue }
            guard let eventIdentifier = event.eventIdentifier else { continue }
            
            foundEventIdentifiers.insert(eventIdentifier)
            
            let timeCategory = TimeCategoryHelper.getTimeCategory(for: event, timeSettings: timeSettings)
            
            // 이미 동기화된 이벤트인지 확인 (calendarEventIdentifier로만 확인)
            let existingTodo = todoStore.todos.first { todo in
                return todo.calendarEventIdentifier == eventIdentifier
            }
            
            if let existing = existingTodo {
                // 기존 항목이 있으면 업데이트 (제목, 메모, 시간대, 시간이 변경되었을 수 있음, 범위와 관계없이)
                var updatedTodo = existing
                updatedTodo.title = event.title
                updatedTodo.memo = event.notes
                updatedTodo.timeCategory = timeCategory
                updatedTodo.startTime = eventStartDate
                todoStore.updateTodo(updatedTodo)
            } else {
                // 새 이벤트는 하루 범위 내에 있는 경우에만 추가
                let isInDayRange = eventStartDate >= dayRangeStart && eventStartDate < dayRangeEnd
                if isInDayRange {
                    let todo = TodoItem(
                        title: event.title,
                        memo: event.notes,
                        type: .mustDo,
                        timeCategory: timeCategory,
                        status: .notStarted,
                        startTime: eventStartDate,
                        calendarEventIdentifier: eventIdentifier
                    )
                    todoStore.addTodo(todo)
                }
            }
        }
        
        // 이미 앱에 있는 이벤트 중 하루 범위 밖으로 이동한 것들은 식별자로 직접 접근해서 업데이트
        for identifier in existingCalendarEventIdentifiers {
            if foundEventIdentifiers.contains(identifier) {
                continue // 이미 처리됨
            }
            
            // 식별자로 직접 접근
            guard let event = eventStore.event(withIdentifier: identifier) else {
                // 이벤트가 삭제된 경우
                if let todo = todoStore.todos.first(where: { $0.calendarEventIdentifier == identifier }) {
                    todoStore.deleteTodo(todo)
                }
                continue
            }
            
            guard let eventStartDate = event.startDate else { continue }
            
            // 하루 범위 밖으로 이동한 경우 앱에서 제거
            if eventStartDate < dayRangeStart || eventStartDate >= dayRangeEnd {
                if let todo = todoStore.todos.first(where: { $0.calendarEventIdentifier == identifier }) {
                    todoStore.deleteTodo(todo)
                }
            }
        }
    }
}

