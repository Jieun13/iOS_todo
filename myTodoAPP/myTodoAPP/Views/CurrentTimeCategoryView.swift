//
//  CurrentTimeCategoryView.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct CurrentTimeCategoryView: View {
    @ObservedObject var todoStore: TodoStore
    @Binding var currentTimeCategory: TimeCategory
    let topHeight: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 헤더
                VStack(spacing: 8) {
                    HStack {
                        // 왼쪽 화살표
                        Button(action: {
                            withAnimation {
                                moveToPreviousTimeCategory()
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(Color.gray.opacity(0.6))
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        // 중앙 텍스트
                        VStack(spacing: 8) {
                            if getIncompleteCount() == 0 {
                                Text("할 일을 다 했어요")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.top, 20)
                            } else {
                                Text("\(getTopTodoTitle()) 할 시간이에요")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.top, 20)
                            }
                            
                            HStack(spacing: 8) {
                                Text(currentTimeCategory.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(MainViewHelper.getCategoryColor(currentTimeCategory))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(MainViewHelper.getCategoryColor(currentTimeCategory).opacity(0.1))
                                    .cornerRadius(12)
                                
                                Text("(\(getIncompleteCount())개 남음)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 오른쪽 화살표
                        Button(action: {
                            withAnimation {
                                moveToNextTimeCategory()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(Color.gray.opacity(0.6))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
                .background(Color(.systemBackground))
                
                // 현재 시간대 할 일 리스트
                if topHeight > 100 {
                    let headerHeight: CGFloat = 120 // 헤더 대략 높이
                    let listHeight = max(0, topHeight - headerHeight)
                    let todos = getCurrentTimeTodos()
                    let categoryColor = MainViewHelper.getCategoryColor(currentTimeCategory)
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(todos) { todo in
                                TodoRowView(
                                    todo: todo,
                                    todoStore: todoStore,
                                    categoryColor: categoryColor,
                                    allowSwipe: true
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    .frame(height: listHeight)
                }
            }
            .frame(height: topHeight, alignment: .top)
            .background(Color(.systemBackground))
            .clipped()
        }
    }
    
    private func getCurrentTimeTodos() -> [TodoItem] {
        return todoStore.getTodos(for: currentTimeCategory)
    }
    
    private func moveToNextTimeCategory() {
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentTimeCategory),
           currentIndex < categories.count - 1 {
            withAnimation {
                currentTimeCategory = categories[currentIndex + 1]
            }
        }
    }
    
    private func moveToPreviousTimeCategory() {
        let categories: [TimeCategory] = [.morning, .daytime, .evening, .night]
        if let currentIndex = categories.firstIndex(of: currentTimeCategory),
           currentIndex > 0 {
            withAnimation {
                currentTimeCategory = categories[currentIndex - 1]
            }
        }
    }
    
    private func getIncompleteCount() -> Int {
        return getCurrentTimeTodos().filter { $0.status != .completed }.count
    }
    
    private func getTopTodoTitle() -> String {
        let todos = getCurrentTimeTodos().filter { $0.status != .completed }
        return todos.first?.title ?? "할 일"
    }
}

