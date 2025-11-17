//
//  AddTodoView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct AddTodoView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var todoStore: TodoStore
    let initialTimeCategory: TimeCategory?
    
    @State private var title: String = ""
    @State private var memo: String = ""
    @State private var selectedType: TodoType = .mustDo
    @State private var selectedTimeCategory: TimeCategory?
    
    init(todoStore: TodoStore, initialTimeCategory: TimeCategory? = nil) {
        self.todoStore = todoStore
        self.initialTimeCategory = initialTimeCategory
        _selectedTimeCategory = State(initialValue: initialTimeCategory)
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
            }
            .navigationTitle("할 일 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveTodo()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveTodo() {
        let newTodo = TodoItem(
            title: title,
            memo: memo.isEmpty ? nil : memo,
            type: selectedType,
            timeCategory: selectedTimeCategory
        )
        todoStore.addTodo(newTodo)
        dismiss()
    }
}

#Preview {
    AddTodoView(todoStore: TodoStore())
}

