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
    let timeSettings: TimeSettings
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
                            // 시간대 표시 (위로 올림)
                            Text(currentTimeCategory.rawValue)
                                .font(.subheadline)
                                .foregroundColor(MainViewHelper.getCategoryColor(currentTimeCategory))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(MainViewHelper.getCategoryColor(currentTimeCategory).opacity(0.1))
                                .cornerRadius(12)
                                .padding(.top, 20)
                            
                            if getIncompleteCount() == 0 {
                                Text("할 일을 다 했어요")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            } else {
                                Text("\(getTopTodoTitle()) 할 시간이에요")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            
                            // 현재 시간대의 종료 시간까지 남은 분 표시
                            let remainingMinutes = getRemainingMinutes()
                            if remainingMinutes > 0 {
                                Text("(\(remainingMinutes)분 남았고 \(getIncompleteCount())개 더 해야해요)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
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
        let (startDate, endDate) = MainViewHelper.getCurrentTimeRange(timeSettings: timeSettings)
        
        let filtered = todoStore.todos.filter { todo in
            return todo.createdAt >= startDate && 
                   todo.createdAt < endDate && 
                   todo.timeCategory == currentTimeCategory
        }
        
        return todoStore.sortTodos(filtered)
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
    
    private func getRemainingMinutes() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 현재 시간의 시간(hour) 확인
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // 자기전 종료 시간 확인
        let nightEndComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.nightEnd)
        guard let nightEndHour = nightEndComponents.hour,
              let nightEndMinute = nightEndComponents.minute else {
            return 0
        }
        let nightEndTimeInMinutes = nightEndHour * 60 + nightEndMinute
        
        let endDate: Date
        
        switch currentTimeCategory {
        case .morning:
            // 아침 종료 시간
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.morningEnd)
            guard let hour = endComponents.hour, let minute = endComponents.minute else { return 0 }
            
            // 자정부터 자기전 종료 시간 사이면 전날의 연장
            if currentTimeInMinutes < nightEndTimeInMinutes {
                // 전날 아침 종료 시간
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday) ?? yesterday
            } else {
                // 오늘 아침 종료 시간
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
            }
            
        case .daytime:
            // 일과 중 종료 시간
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.daytimeEnd)
            guard let hour = endComponents.hour, let minute = endComponents.minute else { return 0 }
            
            // 자정부터 자기전 종료 시간 사이면 전날의 연장
            if currentTimeInMinutes < nightEndTimeInMinutes {
                // 전날 일과 중 종료 시간
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday) ?? yesterday
            } else {
                // 오늘 일과 중 종료 시간
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
            }
            
        case .evening:
            // 귀가 후 종료 시간
            let endComponents = calendar.dateComponents([.hour, .minute], from: timeSettings.eveningEnd)
            guard let hour = endComponents.hour, let minute = endComponents.minute else { return 0 }
            
            // 자정부터 자기전 종료 시간 사이면 전날의 연장
            if currentTimeInMinutes < nightEndTimeInMinutes {
                // 전날 귀가 후 종료 시간
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: yesterday) ?? yesterday
            } else {
                // 오늘 귀가 후 종료 시간
                endDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
            }
            
        case .night:
            // 자기 전 종료 시간
            // 자정부터 자기전 종료 시간 사이면 오늘 자기전 종료 시간
            // 그 외에는 익일 자기전 종료 시간
            if currentTimeInMinutes < nightEndTimeInMinutes {
                // 오늘 자기전 종료 시간
                endDate = calendar.date(bySettingHour: nightEndHour, minute: nightEndMinute, second: 0, of: today) ?? today
            } else {
                // 익일 자기전 종료 시간
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
                endDate = calendar.date(bySettingHour: nightEndHour, minute: nightEndMinute, second: 0, of: tomorrow) ?? tomorrow
            }
        }
        
        let timeInterval = endDate.timeIntervalSince(now)
        let minutes = Int(timeInterval / 60)
        
        return max(0, minutes)
    }
}

