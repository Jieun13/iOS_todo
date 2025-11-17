//
//  AllTodosExpansionState.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import SwiftUI

enum AllTodosExpansionState {
    case collapsed      // 접힘 (최소 높이)
    case medium         // 중간 높이
    case expanded       // 최대 높이
    
    func next() -> AllTodosExpansionState {
        switch self {
        case .collapsed:
            return .medium
        case .medium:
            return .expanded
        case .expanded:
            return .collapsed
        }
    }
    
    func heightRatio() -> CGFloat {
        switch self {
        case .collapsed:
            return 0.08  // 약 60px
        case .medium:
            return 0.4   // 40%
        case .expanded:
            return 0.8   // 80%
        }
    }
}

