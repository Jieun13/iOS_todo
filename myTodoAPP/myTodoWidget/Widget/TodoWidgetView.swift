//
//  TodoWidgetView.swift
//  myTodoAPP
//
//  Created on 11/19/25.
//

import WidgetKit
import SwiftUI

struct TodoWidgetView: View {
    var entry: TodoWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            // Small 사이즈만 지원
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (2x2)
struct SmallWidgetView: View {
    var entry: TodoWidgetProvider.Entry
    
    var body: some View {
        VStack(spacing: 5) {
            // 이모지
            Text(getCategoryEmoji(entry.currentTimeCategory))
                .font(.system(size: 32))
            
            // 시간대 이름
            Text(entry.currentTimeCategory.rawValue)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(getCategoryColor(entry.currentTimeCategory))
            
            Divider()
                .frame(width: 120)
                .foregroundColor(.gray)
                .padding(.vertical, 5)
            
            // 남은 시간
            HStack(spacing: 0) {
                Text("\(formatTimeRemainingMinutes(entry.timeRemaining))")
                    .foregroundColor(getCategoryColor(entry.currentTimeCategory))
                Text("분 남았고")
                    .foregroundColor(.black)
            }
            .font(.subheadline)
            
            // 남은 할 일 개수
            if entry.remainingTodosCount == 0 {
                Text("다 했어요!")
                    .font(.subheadline)
                    .foregroundColor(.black)
            } else {
                HStack(spacing: 0) {
                    Text("\(entry.remainingTodosCount)")
                        .foregroundColor(getCategoryColor(entry.currentTimeCategory))
                    Text("개 더 해야 해요.")
                        .foregroundColor(.black)
                }
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
    
    private func formatTimeRemaining(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        return "\(minutes)분 남았고"
    }
    
    private func formatTimeRemainingMinutes(_ timeInterval: TimeInterval) -> Int {
        return Int(timeInterval) / 60
    }
}

// MARK: - Helper
private func getCategoryEmoji(_ category: TimeCategory) -> String {
    switch category {
    case .morning: return "☀️"
    case .daytime: return "🏫"
    case .evening: return "🏙️"
    case .night: return "🌙"
    }
}

// MARK: - Helper
private func getCategoryColor(_ category: TimeCategory) -> Color {
    switch category {
    case .morning: return .red
    case .daytime: return .orange
    case .evening: return .green
    case .night: return .blue
    }
}

// MARK: - Previews
#Preview("Small", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: Date(),
        currentTimeCategory: .morning,
        todos: [
            TodoItem(
                title: "샘플 할 일 1",
                type: .mustDo,
                timeCategory: .morning,
                status: .notStarted
            ),
            TodoItem(
                title: "샘플 할 일 2",
                type: .mustDo,
                timeCategory: .morning,
                status: .inProgress
            ),
            TodoItem(
                title: "샘플 할 일 3",
                type: .mustDo,
                timeCategory: .morning,
                status: .completed
            )
        ],
        timeSettings: TimeSettings.defaultSettings,
        timeRemaining: 2280,
        remainingTodosCount: 3
    )
}

#Preview("Empty", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: Date(),
        currentTimeCategory: .night,
        todos: [],
        timeSettings: TimeSettings.defaultSettings,
        timeRemaining: 143400,
        remainingTodosCount: 0
    )
}

