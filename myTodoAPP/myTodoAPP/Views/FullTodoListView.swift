//
//  FullTodoListView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

struct FullTodoListView: View {
    @ObservedObject var todoStore: TodoStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: TimeCategory? = nil
    
    var filteredTodos: [TodoItem] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        var todos = todoStore.todos.filter { todo in
            let todoDate = Calendar.current.startOfDay(for: todo.createdAt)
            return todoDate >= today && todoDate < tomorrow
        }
        
        if let category = selectedCategory {
            todos = todos.filter { $0.timeCategory == category }
        }
        
        return todoStore.sortTodos(todos)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 필터 바
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterButton(
                            title: "전체",
                            isSelected: selectedCategory == nil,
                            color: .gray
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(TimeCategory.allCases, id: \.self) { category in
                            FilterButton(
                                title: category.rawValue,
                                isSelected: selectedCategory == category,
                                color: getCategoryColor(category)
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
                
                // 할 일 리스트
                if filteredTodos.isEmpty {
                    VStack {
                        Spacer()
                        Text("할 일이 없습니다")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTodos) { todo in
                                TodoRowView(
                                    todo: todo,
                                    todoStore: todoStore,
                                    categoryColor: todo.timeCategory.map { getCategoryColor($0) } ?? .gray,
                                    allowSwipe: false
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("전체 할 일 (\(filteredTodos.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getCategoryColor(_ category: TimeCategory) -> Color {
        switch category {
        case .morning: return .red
        case .daytime: return .orange
        case .evening: return .green
        case .night: return .blue
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? color : color.opacity(0.1))
                .cornerRadius(20)
        }
    }
}
