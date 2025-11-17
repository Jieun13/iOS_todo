//
//  TodoRowView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct TodoRowView: View {
    let todo: TodoItem
    let todoStore: TodoStore
    let categoryColor: Color
    let allowSwipe: Bool
    @StateObject private var calendarSyncService = CalendarSyncService()
    @State private var showingDetail = false
    
    init(todo: TodoItem, todoStore: TodoStore, categoryColor: Color, allowSwipe: Bool = false) {
        self.todo = todo
        self.todoStore = todoStore
        self.categoryColor = categoryColor
        self.allowSwipe = allowSwipe
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 체크박스
            Button(action: {
                let previousStatus = todo.status
                todoStore.toggleStatus(todo)
                // 완료 상태가 되면 미리알림도 완료 처리
                // toggleStatus는 진행중 → 완료로 전환하므로, previousStatus가 .inProgress면 완료로 전환됨
                if previousStatus == .inProgress {
                    // 진행중에서 완료로 전환된 경우 - 업데이트된 todo를 가져와서 미리알림 완료 처리
                    if let updatedTodo = todoStore.todos.first(where: { $0.id == todo.id }),
                       updatedTodo.status == .completed {
                        calendarSyncService.completeReminder(for: updatedTodo)
                    }
                }
            }) {
                Group {
                    switch todo.status {
                    case .notStarted:
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    case .inProgress:
                        Image(systemName: "circle.fill")
                            .foregroundColor(categoryColor.opacity(0.5))
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(categoryColor)
                    }
                }
                .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                // 제목
                Text(todo.title)
                    .font(.body)
                    .foregroundColor(todo.status == .completed ? .gray : .primary)
                    .strikethrough(todo.status == .completed)
                
                // 메모
                if let memo = todo.memo, !memo.isEmpty {
                    Text(memo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .strikethrough(todo.status == .completed)
                }
                
                // 시간대 표시
                HStack(spacing: 6) {
                    if let timeCategory = todo.timeCategory {
                        Text(timeCategory.rawValue)
                            .font(.caption2)
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Text(todo.type.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 오른쪽 화살표 버튼 (다음 시간대로 이동)
            if allowSwipe && canMoveToNextTimeCategory() {
                Button(action: {
                    todoStore.moveTodoToNextTimeCategory(todo)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(categoryColor)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TodoDetailView(todo: todo, todoStore: todoStore)
        }
    }
    
    private var backgroundColor: Color {
        switch todo.status {
        case .notStarted:
            return Color(.systemBackground)
        case .inProgress:
            return categoryColor.opacity(0.1)
        case .completed:
            return Color.gray.opacity(0.1)
        }
    }
    
    private func canMoveToNextTimeCategory() -> Bool {
        guard let currentCategory = todo.timeCategory else { return false }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex < categories.count - 1 {
            return true
        }
        return false
    }
}

#Preview {
    let sampleTodo = TodoItem(
        title: "샘플 할 일",
        memo: "이것은 샘플 메모입니다",
        type: .mustDo,
        timeCategory: .morning,
        status: .notStarted
    )
    let todoStore = TodoStore()
    
    VStack {
        TodoRowView(todo: sampleTodo, todoStore: todoStore, categoryColor: .red, allowSwipe: true)
        TodoRowView(
            todo: TodoItem(
                title: "완료된 할 일",
                type: .wantToDo,
                timeCategory: .evening,
                status: .completed
            ),
            todoStore: todoStore,
            categoryColor: .green,
            allowSwipe: false
        )
    }
    .padding()
}

