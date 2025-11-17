//
//  TimeCategoryDropDelegate.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct TimeCategoryDropDelegate: DropDelegate {
    let targetCategory: TimeCategory?
    let todoStore: TodoStore
    let currentTimeCategory: TimeCategory
    
    func performDrop(info: DropInfo) -> Bool {
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            return false
        }
        
        _ = itemProvider.loadObject(ofClass: NSString.self) { (string, error) in
            guard let uuidString = string as? String,
                  let uuid = UUID(uuidString: uuidString),
                  let todo = todoStore.todos.first(where: { $0.id == uuid }) else {
                return
            }
            
            DispatchQueue.main.async {
                todoStore.moveTodoToTimeCategory(todo, timeCategory: currentTimeCategory)
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
    }
    
    func dropExited(info: DropInfo) {
    }
}

