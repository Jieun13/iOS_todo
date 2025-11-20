//
//  ReminderOperations.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import EventKit

struct ReminderOperations {
    let eventStore: EKEventStore
    
    func createReminder(for todo: TodoItem, timeSettings: TimeSettings) -> String? {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized else { return nil }
        
        let calendars = eventStore.calendars(for: .reminder)
        guard let defaultCalendar = calendars.first else { return nil }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = todo.title
        reminder.notes = todo.memo
        reminder.calendar = defaultCalendar
        
        // 앱에서 생성한 할 일은 시간 설정하지 않고 날짜만 설정 (시간 없는 상태)
        let calendar = Calendar.current
        let today = Date()
        reminder.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        } catch {
            print("미리알림 생성 실패: \(error)")
            return nil
        }
    }
    
    func updateReminder(for todo: TodoItem, timeSettings: TimeSettings) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized,
              let reminderIdentifier = todo.reminderIdentifier else { return }
        
        // 식별자로 직접 접근
        guard let calendarItem = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            print("미리알림을 찾을 수 없음: \(reminderIdentifier)")
            return
        }
        
        calendarItem.title = todo.title
        calendarItem.notes = todo.memo
        
        // 앱에서 생성한 할 일은 시간 설정하지 않고 날짜만 설정 (시간 없는 상태)
        let calendar = Calendar.current
        let today = Date()
        calendarItem.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        do {
            try eventStore.save(calendarItem, commit: true)
        } catch {
            print("미리알림 업데이트 실패: \(error)")
        }
    }
    
    func removeReminderTime(for todo: TodoItem) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized,
              let reminderIdentifier = todo.reminderIdentifier else { return }
        
        // 식별자로 직접 접근
        guard let calendarItem = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            print("미리알림을 찾을 수 없음: \(reminderIdentifier)")
            return
        }
        
        // 미리알림에서 시간 제거 (날짜만 유지)
        let calendar = Calendar.current
        let today = Date()
        calendarItem.dueDateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        do {
            try eventStore.save(calendarItem, commit: true)
        } catch {
            print("미리알림 시간 제거 실패: \(error)")
        }
    }
    
    func deleteReminder(for todo: TodoItem) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized,
              let reminderIdentifier = todo.reminderIdentifier else { return }
        
        // 식별자로 직접 접근
        guard let calendarItem = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            print("미리알림을 찾을 수 없음: \(reminderIdentifier)")
            return
        }
        
        do {
            try eventStore.remove(calendarItem, commit: true)
        } catch {
            print("미리알림 삭제 실패: \(error)")
        }
    }
    
    func completeReminder(for todo: TodoItem) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized,
              let reminderIdentifier = todo.reminderIdentifier else { return }
        
        // 식별자로 직접 접근
        guard let calendarItem = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            print("미리알림을 찾을 수 없음: \(reminderIdentifier)")
            return
        }
        
        do {
            calendarItem.isCompleted = true
            calendarItem.completionDate = Date()
            try eventStore.save(calendarItem, commit: true)
        } catch {
            print("미리알림 완료 처리 실패: \(error)")
        }
    }
    
    func incompleteReminder(for todo: TodoItem) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .authorized,
              let reminderIdentifier = todo.reminderIdentifier else { return }
        
        // 식별자로 직접 접근
        guard let calendarItem = eventStore.calendarItem(withIdentifier: reminderIdentifier) as? EKReminder else {
            print("미리알림을 찾을 수 없음: \(reminderIdentifier)")
            return
        }
        
        do {
            calendarItem.isCompleted = false
            calendarItem.completionDate = nil
            try eventStore.save(calendarItem, commit: true)
        } catch {
            print("미리알림 미완료 처리 실패: \(error)")
        }
    }
}

