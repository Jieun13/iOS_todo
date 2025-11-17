//
//  AllTodosView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct AllTodosView: View {
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var timeSettingsStore: TimeSettingsStore
    @Binding var todoFilterType: TodoFilterType
    @Binding var allTodosExpansionState: AllTodosExpansionState
    @Binding var currentTimeCategory: TimeCategory
    let bottomHeight: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더와 필터
            VStack(spacing: 8) {
                HStack {
                    Text("전체 할 일")
                        .font(.headline)
                    Text("(\(getFilteredTodosCount())개)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    // 화살표 버튼
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            allTodosExpansionState = allTodosExpansionState.next()
                        }
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.subheadline)
                            .foregroundColor(Color.gray.opacity(0.6))
                            .rotationEffect(.degrees(allTodosExpansionState == .expanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: allTodosExpansionState)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        allTodosExpansionState = allTodosExpansionState.next()
                    }
                }
                
                // 필터 버튼
                if bottomHeight > 80 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            FilterButton(
                                title: "시간대별",
                                isSelected: todoFilterType == .timeCategory,
                                color: .gray
                            ) {
                                todoFilterType = .timeCategory
                            }
                            
                            FilterButton(
                                title: "해야할일",
                                isSelected: todoFilterType == .mustDo,
                                color: Color(white: 0.3)
                            ) {
                                todoFilterType = .mustDo
                            }
                            
                            FilterButton(
                                title: "하고싶은일",
                                isSelected: todoFilterType == .wantToDo,
                                color: Color(white: 0.6)
                            ) {
                                todoFilterType = .wantToDo
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }
            }
            
            // 할 일 리스트
            if bottomHeight > 80 {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if todoFilterType == .timeCategory {
                            // 시간대별 보기
                            ForEach(TimeCategory.allCases + [nil], id: \.self) { category in
                                let todos = MainViewHelper.getTodosForCategory(category, from: todoStore, timeSettings: timeSettingsStore.settings)
                                if !todos.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(category?.rawValue ?? "시간대 미지정")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(category.map { MainViewHelper.getCategoryColor($0) } ?? .gray)
                                            Text("(\(todos.count))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                        
                                        ForEach(todos) { todo in
                                            TodoRowView(
                                                todo: todo,
                                                todoStore: todoStore,
                                                categoryColor: category.map { MainViewHelper.getCategoryColor($0) } ?? .gray,
                                                allowSwipe: false
                                            )
                                            .padding(.horizontal)
                                            .onDrag {
                                                NSItemProvider(object: todo.id.uuidString as NSString)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(category.map { MainViewHelper.getCategoryColor($0).opacity(0.05) } ?? Color.gray.opacity(0.05))
                                            .padding(.horizontal, 8)
                                    )
                                    .onDrop(of: [.text], delegate: TimeCategoryDropDelegate(
                                        targetCategory: category,
                                        todoStore: todoStore,
                                        currentTimeCategory: currentTimeCategory
                                    ))
                                }
                            }
                        } else {
                            // 타입별 보기
                            let filteredTodos = MainViewHelper.getTodosByType(
                                todoFilterType == .mustDo ? .mustDo : .wantToDo,
                                from: todoStore,
                                timeSettings: timeSettingsStore.settings
                            )
                            let backgroundColor = todoFilterType == .mustDo ? Color(white: 0.3).opacity(0.1) : Color(white: 0.6).opacity(0.1)
                            
                            if !filteredTodos.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(filteredTodos) { todo in
                                        TodoRowView(
                                            todo: todo,
                                            todoStore: todoStore,
                                            categoryColor: todo.timeCategory.map { MainViewHelper.getCategoryColor($0) } ?? .gray,
                                            allowSwipe: false
                                        )
                                        .padding(.horizontal)
                                        .onDrag {
                                            NSItemProvider(object: todo.id.uuidString as NSString)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(backgroundColor)
                                        .padding(.horizontal, 8)
                                )
                                .onDrop(of: [.text], delegate: TimeCategoryDropDelegate(
                                    targetCategory: nil,
                                    todoStore: todoStore,
                                    currentTimeCategory: currentTimeCategory
                                ))
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .contentShape(Rectangle())
                .frame(maxHeight: .infinity)
            }
        }
        .frame(height: bottomHeight)
        .background(Color(.systemGroupedBackground))
    }
    
    private func getFilteredTodosCount() -> Int {
        switch todoFilterType {
        case .timeCategory:
            return MainViewHelper.getTodayTodos(from: todoStore, timeSettings: timeSettingsStore.settings).count
        case .mustDo:
            return MainViewHelper.getTodosByType(.mustDo, from: todoStore, timeSettings: timeSettingsStore.settings).count
        case .wantToDo:
            return MainViewHelper.getTodosByType(.wantToDo, from: todoStore, timeSettings: timeSettingsStore.settings).count
        }
    }
}

