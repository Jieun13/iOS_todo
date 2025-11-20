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
                    // 상태 변경에 따라 미리알림도 업데이트
                    if let updatedTodo = todoStore.todos.first(where: { $0.id == todo.id }) {
                        if updatedTodo.status == .completed && previousStatus != .completed {
                            // 완료 상태로 전환된 경우
                            calendarSyncService.completeReminder(for: updatedTodo)
                        } else if updatedTodo.status != .completed && previousStatus == .completed {
                            // 완료 상태에서 미완료로 전환된 경우
                            calendarSyncService.incompleteReminder(for: updatedTodo)
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
                        
                        // 시간 정보 표시 (startTime이 있는 경우에만)
                        if let startTime = todo.startTime {
                            Text(formatTime(startTime))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(todo.type.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 미루기 버튼들 (오른쪽에 항상 표시)
                if allowSwipe && todo.timeCategory != nil && todo.status != .completed {
                    HStack(spacing: 8) {
                        // 이전 시간대로 이동 버튼
                        if canMoveToPreviousTimeCategory() {
                            Button(action: {
                                todoStore.moveTodoToPreviousTimeCategory(todo, calendarSyncService: calendarSyncService)
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(getPreviousTimeCategoryColor())
                                    .frame(width: 45, height: 40)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(getPreviousTimeCategoryColor(), lineWidth: 1.5)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                        
                        // 다음 시간대로 이동 버튼
                        if canMoveToNextTimeCategory() {
                            Button(action: {
                                todoStore.moveTodoToNextTimeCategory(todo, calendarSyncService: calendarSyncService)
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(getNextTimeCategoryColor())
                                    .frame(width: 45, height: 40)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(getNextTimeCategoryColor(), lineWidth: 1.5)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryColor.opacity(0.3), lineWidth: 2)
        )
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            TodoDetailView(todo: todo, todoStore: todoStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    
    private func canMoveToPreviousTimeCategory() -> Bool {
        guard let currentCategory = todo.timeCategory else { return false }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex > 0 {
            return true
        }
        return false
    }
    
    private func formatTime(_ date: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ko_KR")
        timeFormatter.dateFormat = "a h:mm"
        return timeFormatter.string(from: date)
    }
    
    private func getPreviousTimeCategoryColor() -> Color {
        guard let currentCategory = todo.timeCategory else { return categoryColor }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex > 0 {
            let previousCategory = categories[currentIndex - 1]
            return MainViewHelper.getCategoryColor(previousCategory)
        }
        return categoryColor
    }
    
    private func getNextTimeCategoryColor() -> Color {
        guard let currentCategory = todo.timeCategory else { return categoryColor }
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentCategory),
           currentIndex < categories.count - 1 {
            let nextCategory = categories[currentIndex + 1]
            return MainViewHelper.getCategoryColor(nextCategory)
        }
        return categoryColor
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

