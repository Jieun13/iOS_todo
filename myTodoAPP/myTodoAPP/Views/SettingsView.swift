//
//  SettingsView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var timeSettingsStore: TimeSettingsStore
    @ObservedObject var todoStore: TodoStore
    @StateObject private var calendarSyncService = CalendarSyncService()
    @State private var isRefreshing = false
    
    @State private var morningStart: Date
    @State private var morningEnd: Date
    @State private var daytimeStart: Date
    @State private var daytimeEnd: Date
    @State private var eveningStart: Date
    @State private var eveningEnd: Date
    @State private var nightStart: Date
    @State private var nightEnd: Date
    
    init(timeSettingsStore: TimeSettingsStore, todoStore: TodoStore) {
        self.timeSettingsStore = timeSettingsStore
        self.todoStore = todoStore
        let settings = timeSettingsStore.settings
        _morningStart = State(initialValue: settings.morningStart)
        _morningEnd = State(initialValue: settings.morningEnd)
        _daytimeStart = State(initialValue: settings.daytimeStart)
        _daytimeEnd = State(initialValue: settings.daytimeEnd)
        _eveningStart = State(initialValue: settings.eveningStart)
        _eveningEnd = State(initialValue: settings.eveningEnd)
        _nightStart = State(initialValue: settings.nightStart)
        _nightEnd = State(initialValue: settings.nightEnd)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("시간대 설정")) {
                    TimeRangeRow(title: "아침", startTime: $morningStart, endTime: $morningEnd, color: .red)
                    TimeRangeRow(title: "일과 중", startTime: $daytimeStart, endTime: $daytimeEnd, color: .orange)
                    TimeRangeRow(title: "귀가 후", startTime: $eveningStart, endTime: $eveningEnd, color: .green)
                    TimeRangeRow(title: "자기 전", startTime: $nightStart, endTime: $nightEnd, color: .blue)
                }
                
                Section(header: Text("동기화")) {
                    Button(action: {
                        refreshSync()
                    }) {
                        HStack {
                            if isRefreshing {
                                ProgressView()
                                    .padding(.trailing, 8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .padding(.trailing, 8)
                            }
                            Text("캘린더 및 미리알림 새로고침")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveSettings()
                    }
                }
            }
        }
    }
    
    private func refreshSync() {
        isRefreshing = true
        Task {
            calendarSyncService.checkAuthorizationStatus()
            if calendarSyncService.isAuthorized {
                calendarSyncService.syncCalendarEvents(to: todoStore, timeSettings: timeSettingsStore.settings)
                calendarSyncService.syncReminders(to: todoStore, timeSettings: timeSettingsStore.settings)
            }
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func saveSettings() {
        timeSettingsStore.settings.morningStart = morningStart
        timeSettingsStore.settings.morningEnd = morningEnd
        timeSettingsStore.settings.daytimeStart = daytimeStart
        timeSettingsStore.settings.daytimeEnd = daytimeEnd
        timeSettingsStore.settings.eveningStart = eveningStart
        timeSettingsStore.settings.eveningEnd = eveningEnd
        timeSettingsStore.settings.nightStart = nightStart
        timeSettingsStore.settings.nightEnd = nightEnd
        timeSettingsStore.save()
        dismiss()
    }
}

struct TimeRangeRow: View {
    let title: String
    @Binding var startTime: Date
    @Binding var endTime: Date
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            DatePicker("시작 시간", selection: $startTime, displayedComponents: .hourAndMinute)
            DatePicker("종료 시간", selection: $endTime, displayedComponents: .hourAndMinute)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView(timeSettingsStore: TimeSettingsStore(), todoStore: TodoStore())
}

