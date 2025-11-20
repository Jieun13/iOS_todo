//
//  TodoWidget.swift
//  myTodoAPP
//
//  Created on 11/19/25.
//

import WidgetKit
import SwiftUI

@main
struct TodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
    }
}

struct TodoWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("할 일")
        .description("현재 시간대의 할 일을 확인하세요.")
        .supportedFamilies([.systemSmall])
    }
}

