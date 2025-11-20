//
//  myTodoWidgetLiveActivity.swift
//  myTodoWidget
//
//  Created by 백지은 on 11/21/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct myTodoWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct myTodoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: myTodoWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension myTodoWidgetAttributes {
    fileprivate static var preview: myTodoWidgetAttributes {
        myTodoWidgetAttributes(name: "World")
    }
}

extension myTodoWidgetAttributes.ContentState {
    fileprivate static var smiley: myTodoWidgetAttributes.ContentState {
        myTodoWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: myTodoWidgetAttributes.ContentState {
         myTodoWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: myTodoWidgetAttributes.preview) {
   myTodoWidgetLiveActivity()
} contentStates: {
    myTodoWidgetAttributes.ContentState.smiley
    myTodoWidgetAttributes.ContentState.starEyes
}
