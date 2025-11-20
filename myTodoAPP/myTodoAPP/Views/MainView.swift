//
//  MainView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI
import WidgetKit

struct MainView: View {
    @StateObject private var todoStore = TodoStore()
    @StateObject private var timeSettingsStore = TimeSettingsStore()
    @StateObject private var calendarSyncService = CalendarSyncService()
    @State private var currentTimeCategory: TimeCategory
    @State private var showingAddTodo = false
    @State private var showingCalendarPermission = false
    @State private var showingFullTodoList = false
    @State private var todoFilterType: TodoFilterType = .mustDo
    @State private var allTodosExpansionState: AllTodosExpansionState = .collapsed
    
    init() {
        let settings = TimeSettings.defaultSettings
        _currentTimeCategory = State(initialValue: settings.getCurrentTimeCategory())
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let screenHeight = geometry.size.height
                let minHeight: CGFloat = 60
                let bottomHeight = max(minHeight, screenHeight * allTodosExpansionState.heightRatio())
                let topHeight = max(0, screenHeight - bottomHeight)
                
                VStack(spacing: 0) {
                    // 상단 - 현재 시간대 할 일
                    CurrentTimeCategoryView(
                        todoStore: todoStore,
                        currentTimeCategory: $currentTimeCategory,
                        timeSettings: timeSettingsStore.settings,
                        topHeight: topHeight
                    )
                    
                    Divider()
                    
                    // 하단 - 전체 할 일 리스트
                    AllTodosView(
                        todoStore: todoStore,
                        timeSettingsStore: timeSettingsStore,
                        todoFilterType: $todoFilterType,
                        allTodosExpansionState: $allTodosExpansionState,
                        currentTimeCategory: $currentTimeCategory,
                        bottomHeight: bottomHeight
                    )
                }
            }
            .navigationTitle("할 일")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTodo = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: SettingsView(timeSettingsStore: timeSettingsStore, todoStore: todoStore)) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                AddTodoView(todoStore: todoStore, initialTimeCategory: currentTimeCategory)
            }
            .sheet(isPresented: $showingFullTodoList) {
                FullTodoListView(todoStore: todoStore, timeSettingsStore: timeSettingsStore)
            }
            .onAppear {
                todoStore.cleanupOldTodos(timeSettings: timeSettingsStore.settings)
                updateCurrentTimeCategory()
                syncWithCalendar()
                reloadWidgets()
            }
            .onChange(of: timeSettingsStore.settings) {
                updateCurrentTimeCategory()
            }
            .onChange(of: calendarSyncService.hasFullAccess) {
                syncWithCalendar()
            }
            .onChange(of: todoStore.todos) { _ in
                // 할 일이 변경될 때마다 위젯 새로고침
                reloadWidgets()
            }
            .alert("캘린더 접근 권한", isPresented: $showingCalendarPermission) {
                Button("설정으로 이동") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("나중에", role: .cancel) { }
            } message: {
                Text("캘린더와 미리알림을 동기화하려면 권한이 필요합니다.\n\n설정 앱에서:\n1. '개인정보 보호 및 보안' 선택\n2. '캘린더' 선택 → 'myTodoAPP' 찾아서 허용\n3. '미리알림' 선택 → 'myTodoAPP' 찾아서 허용\n\n권한 허용 후 앱으로 돌아오면 자동으로 동기화됩니다.")
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                todoStore.cleanupOldTodos(timeSettings: timeSettingsStore.settings)
                syncWithCalendar()
                reloadWidgets()
            }
        }
    }
    
    private func updateCurrentTimeCategory() {
        currentTimeCategory = timeSettingsStore.settings.getCurrentTimeCategory()
    }
    
    private func syncWithCalendar() {
        Task {
            calendarSyncService.checkAuthorizationStatus()
            
            if !calendarSyncService.isAuthorized {
                _ = await calendarSyncService.requestAccess()
                calendarSyncService.checkAuthorizationStatus()
                
                if !calendarSyncService.isAuthorized {
                    await MainActor.run {
                        showingCalendarPermission = true
                    }
                }
            }
            
            if calendarSyncService.isAuthorized {
                calendarSyncService.syncCalendarEvents(to: todoStore, timeSettings: timeSettingsStore.settings)
                calendarSyncService.syncReminders(to: todoStore, timeSettings: timeSettingsStore.settings)
            }
        }
    }
    
    private func reloadWidgets() {
        // 위젯 새로고침 (할 일 개수 업데이트)
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
    }
}

#Preview {
    MainView()
}
