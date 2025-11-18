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
    
    private var calendarEventSync: CalendarEventSync {
        CalendarEventSync(eventStore: eventStore)
    }
    
    private var reminderSync: ReminderSync {
        ReminderSync(eventStore: eventStore)
    }
    
    private var reminderOperations: ReminderOperations {
        ReminderOperations(eventStore: eventStore)
    }
    
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
        guard hasFullAccess else { return }
        calendarEventSync.syncCalendarEvents(to: todoStore, timeSettings: timeSettings)
    }
    
    func syncReminders(to todoStore: TodoStore, timeSettings: TimeSettings) {
        guard hasFullAccess else { return }
        reminderSync.syncReminders(to: todoStore, timeSettings: timeSettings)
    }
    
    func createReminder(for todo: TodoItem, timeSettings: TimeSettings) -> String? {
        guard hasFullAccess else { return nil }
        return reminderOperations.createReminder(for: todo, timeSettings: timeSettings)
    }
    
    func updateReminder(for todo: TodoItem, timeSettings: TimeSettings) {
        guard hasFullAccess else { return }
        reminderOperations.updateReminder(for: todo, timeSettings: timeSettings)
    }
    
    func removeReminderTime(for todo: TodoItem) {
        guard hasFullAccess else { return }
        reminderOperations.removeReminderTime(for: todo)
    }
    
    func deleteReminder(for todo: TodoItem) {
        guard hasFullAccess else { return }
        reminderOperations.deleteReminder(for: todo)
    }
    
    func completeReminder(for todo: TodoItem) {
        guard hasFullAccess else { return }
        reminderOperations.completeReminder(for: todo)
    }
}

