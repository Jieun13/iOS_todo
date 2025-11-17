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
    
    @State private var title: String
    @State private var memo: String
    @State private var selectedType: TodoType
    @State private var selectedTimeCategory: TimeCategory?
    
    init(todo: TodoItem, todoStore: TodoStore) {
        self.todo = todo
        self.todoStore = todoStore
        _title = State(initialValue: todo.title)
        _memo = State(initialValue: todo.memo ?? "")
        _selectedType = State(initialValue: todo.type)
        _selectedTimeCategory = State(initialValue: todo.timeCategory)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("할 일 정보")) {
                    TextField("제목", text: $title)
                    
                    TextField("메모 (선택사항)", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
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
                        todoStore.deleteTodo(todo)
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
        var updatedTodo = todo
        updatedTodo.title = title
        updatedTodo.memo = memo.isEmpty ? nil : memo
        updatedTodo.type = selectedType
        updatedTodo.timeCategory = selectedTimeCategory
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

