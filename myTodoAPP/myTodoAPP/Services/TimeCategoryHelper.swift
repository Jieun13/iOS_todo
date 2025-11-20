//
//  TimeCategoryHelper.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import EventKit

struct TimeCategoryHelper {
    static func getTimeCategory(for event: EKEvent, timeSettings: TimeSettings) -> TimeCategory? {
        guard let startDate = event.startDate else { return nil }
        return getTimeCategory(for: startDate, timeSettings: timeSettings)
    }
    
    static func getTimeCategory(for reminder: EKReminder, timeSettings: TimeSettings) -> TimeCategory? {
        guard let dueDateComponents = reminder.dueDateComponents else {
            return nil
        }
        let calendar = Calendar.current
        guard let dueDate = calendar.date(from: dueDateComponents) else {
            return nil
        }
        return getTimeCategory(for: dueDate, timeSettings: timeSettings)
    }
    
    static func getTimeCategory(for date: Date, timeSettings: TimeSettings) -> TimeCategory? {
        let calendar = Calendar.current
        let dateMinute = calendar.component(.minute, from: date)
        let dateTimeInMinutes = calendar.component(.hour, from: date) * 60 + dateMinute
        
        // 설정된 시간대를 사용하여 시간대 결정
        let morningStartMinutes = calendar.component(.hour, from: timeSettings.morningStart) * 60 + calendar.component(.minute, from: timeSettings.morningStart)
        let morningEndMinutes = calendar.component(.hour, from: timeSettings.morningEnd) * 60 + calendar.component(.minute, from: timeSettings.morningEnd)
        let daytimeStartMinutes = calendar.component(.hour, from: timeSettings.daytimeStart) * 60 + calendar.component(.minute, from: timeSettings.daytimeStart)
        let daytimeEndMinutes = calendar.component(.hour, from: timeSettings.daytimeEnd) * 60 + calendar.component(.minute, from: timeSettings.daytimeEnd)
        let eveningStartMinutes = calendar.component(.hour, from: timeSettings.eveningStart) * 60 + calendar.component(.minute, from: timeSettings.eveningStart)
        let eveningEndMinutes = calendar.component(.hour, from: timeSettings.eveningEnd) * 60 + calendar.component(.minute, from: timeSettings.eveningEnd)
        let nightStartMinutes = calendar.component(.hour, from: timeSettings.nightStart) * 60 + calendar.component(.minute, from: timeSettings.nightStart)
        let nightEndMinutes = calendar.component(.hour, from: timeSettings.nightEnd) * 60 + calendar.component(.minute, from: timeSettings.nightEnd)
        
        // 시간대 범위 확인 (자정을 넘어가는 경우 처리)
        if morningStartMinutes <= morningEndMinutes {
            // 일반적인 경우 (예: 6시 ~ 9시)
            if dateTimeInMinutes >= morningStartMinutes && dateTimeInMinutes < morningEndMinutes {
                return .morning
            }
        } else {
            // 자정을 넘어가는 경우 (예: 22시 ~ 6시)
            if dateTimeInMinutes >= morningStartMinutes || dateTimeInMinutes < morningEndMinutes {
                return .morning
            }
        }
        
        if daytimeStartMinutes <= daytimeEndMinutes {
            if dateTimeInMinutes >= daytimeStartMinutes && dateTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        } else {
            if dateTimeInMinutes >= daytimeStartMinutes || dateTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        }
        
        if eveningStartMinutes <= eveningEndMinutes {
            if dateTimeInMinutes >= eveningStartMinutes && dateTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        } else {
            if dateTimeInMinutes >= eveningStartMinutes || dateTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        }
        
        if nightStartMinutes <= nightEndMinutes {
            if dateTimeInMinutes >= nightStartMinutes && dateTimeInMinutes < nightEndMinutes {
                return .night
            }
        } else {
            if dateTimeInMinutes >= nightStartMinutes || dateTimeInMinutes < nightEndMinutes {
                return .night
            }
        }
        
        // 기본값 (어떤 시간대에도 해당하지 않는 경우)
        return .daytime
    }
}

