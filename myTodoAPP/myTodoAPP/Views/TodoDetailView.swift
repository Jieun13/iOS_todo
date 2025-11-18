//
//  TodoDetailView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct TodoDetailView: View {
    @Environment(\.dismiss) var dismiss
    let todo: TodoItem
    @ObservedObject var todoStore: TodoStore
    @StateObject private var calendarSyncService = CalendarSyncService()
    @StateObject private var timeSettingsStore = TimeSettingsStore()
    
    @State private var title: String
    @State private var memo: String
    @State private var selectedType: TodoType
    @State private var selectedTimeCategory: TimeCategory?
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title, memo
    }
    
    init(todo: TodoItem, todoStore: TodoStore) {
        self.todo = todo
        self.todoStore = todoStore
        _title = State(initialValue: todo.title)
        _memo = State(initialValue: todo.memo ?? "")
        _selectedType = State(initialValue: todo.type)
        _selectedTimeCategory = State(initialValue: todo.timeCategory)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("할 일 정보")) {
                    TextField("제목", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .memo
                        }
                    
                    TextField("메모 (선택사항)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .focused($focusedField, equals: .memo)
                }
                
                Section(header: Text("분류")) {
                    Picker("유형", selection: $selectedType) {
                        Text("해야 할 일").tag(TodoType.mustDo)
                        Text("하고 싶은 일").tag(TodoType.wantToDo)
                    }
                    
                    Picker("시간대", selection: Binding(
                        get: { selectedTimeCategory },
                        set: { selectedTimeCategory = $0 }
                    )) {
                        Text("지정 안 함").tag(Optional<TimeCategory>(nil))
                        ForEach(TimeCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        todoStore.deleteTodoWithReminder(todo, calendarSyncService: calendarSyncService)
                        dismiss()
                    } label: {
                        Text("삭제")
                    }
                }
            }
            .navigationTitle("할 일 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // todoStore에서 최신 todo를 가져와서 업데이트
        guard let currentTodo = todoStore.todos.first(where: { $0.id == todo.id }) else {
            dismiss()
            return
        }
        
        var updatedTodo = currentTodo
        updatedTodo.title = title
        updatedTodo.memo = memo.isEmpty ? nil : memo
        updatedTodo.type = selectedType
        updatedTodo.timeCategory = selectedTimeCategory
        
        // 미리알림 업데이트 또는 생성
        if calendarSyncService.isAuthorized {
            if let reminderIdentifier = updatedTodo.reminderIdentifier {
                // 앱에서 생성한 할 일(startTime == nil)은 시간대 변경 시 미리알림 업데이트 불필요
                // 제목이나 메모가 변경된 경우에만 업데이트
                let titleChanged = currentTodo.title != updatedTodo.title
                let memoChanged = currentTodo.memo != updatedTodo.memo
                
                if updatedTodo.startTime == nil {
                    // 앱에서 생성한 할 일: 제목/메모 변경 시에만 업데이트
                    if titleChanged || memoChanged {
                        calendarSyncService.updateReminder(for: updatedTodo, timeSettings: timeSettingsStore.settings)
                    }
                } else {
                    // 캘린더/미리알림에서 가져온 할 일: 항상 업데이트
                    calendarSyncService.updateReminder(for: updatedTodo, timeSettings: timeSettingsStore.settings)
                }
            } else {
                // 미리알림이 없으면 새로 생성
                if let newReminderIdentifier = calendarSyncService.createReminder(for: updatedTodo, timeSettings: timeSettingsStore.settings) {
                    updatedTodo.reminderIdentifier = newReminderIdentifier
                }
            }
        }
        
        todoStore.updateTodo(updatedTodo)
        dismiss()
    }
}

#Preview {
    let sampleTodo = TodoItem(
        title: "편집할 할 일",
        memo: "이것은 편집 가능한 샘플입니다",
        type: .mustDo,
        timeCategory: .daytime,
        status: .notStarted
    )
    TodoDetailView(todo: sampleTodo, todoStore: TodoStore())
}

