//
//  TimeSettings.swift
//  myTodoAPP
//
//  Created by 백지은 on 11/17/25.
//

import Foundation
import Combine

struct TimeSettings: Codable, Equatable {
    var morningStart: Date
    var morningEnd: Date
    var daytimeStart: Date
    var daytimeEnd: Date
    var eveningStart: Date
    var eveningEnd: Date
    var nightStart: Date
    var nightEnd: Date
    
    static let defaultSettings: TimeSettings = {
        let calendar = Calendar.current
        let now = Date()
        
        return TimeSettings(
            morningStart: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now,
            morningEnd: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now,
            daytimeStart: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now,
            daytimeEnd: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now,
            eveningStart: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now,
            eveningEnd: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now,
            nightStart: calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now,
            nightEnd: calendar.date(bySettingHour: 6, minute: 0, second: 0, of: now) ?? now
        )
    }()
    
    func getCurrentTimeCategory() -> TimeCategory {
        let now = Date()
        let calendar = Calendar.current
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = calendar.component(.hour, from: now) * 60 + currentMinute
        
        // 설정된 시간대를 사용하여 현재 시간대 결정
        let morningStartMinutes = calendar.component(.hour, from: morningStart) * 60 + calendar.component(.minute, from: morningStart)
        let morningEndMinutes = calendar.component(.hour, from: morningEnd) * 60 + calendar.component(.minute, from: morningEnd)
        let daytimeStartMinutes = calendar.component(.hour, from: daytimeStart) * 60 + calendar.component(.minute, from: daytimeStart)
        let daytimeEndMinutes = calendar.component(.hour, from: daytimeEnd) * 60 + calendar.component(.minute, from: daytimeEnd)
        let eveningStartMinutes = calendar.component(.hour, from: eveningStart) * 60 + calendar.component(.minute, from: eveningStart)
        let eveningEndMinutes = calendar.component(.hour, from: eveningEnd) * 60 + calendar.component(.minute, from: eveningEnd)
        let nightStartMinutes = calendar.component(.hour, from: nightStart) * 60 + calendar.component(.minute, from: nightStart)
        let nightEndMinutes = calendar.component(.hour, from: nightEnd) * 60 + calendar.component(.minute, from: nightEnd)
        
        // 시간대 범위 확인 (자정을 넘어가는 경우 처리)
        if morningStartMinutes <= morningEndMinutes {
            // 일반적인 경우 (예: 6시 ~ 9시)
            if currentTimeInMinutes >= morningStartMinutes && currentTimeInMinutes < morningEndMinutes {
                return .morning
            }
        } else {
            // 자정을 넘어가는 경우 (예: 22시 ~ 6시)
            if currentTimeInMinutes >= morningStartMinutes || currentTimeInMinutes < morningEndMinutes {
                return .morning
            }
        }
        
        if daytimeStartMinutes <= daytimeEndMinutes {
            if currentTimeInMinutes >= daytimeStartMinutes && currentTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        } else {
            if currentTimeInMinutes >= daytimeStartMinutes || currentTimeInMinutes < daytimeEndMinutes {
                return .daytime
            }
        }
        
        if eveningStartMinutes <= eveningEndMinutes {
            if currentTimeInMinutes >= eveningStartMinutes && currentTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        } else {
            if currentTimeInMinutes >= eveningStartMinutes || currentTimeInMinutes < eveningEndMinutes {
                return .evening
            }
        }
        
        if nightStartMinutes <= nightEndMinutes {
            if currentTimeInMinutes >= nightStartMinutes && currentTimeInMinutes < nightEndMinutes {
                return .night
            }
        } else {
            if currentTimeInMinutes >= nightStartMinutes || currentTimeInMinutes < nightEndMinutes {
                return .night
            }
        }
        
        // 기본값 (어떤 시간대에도 해당하지 않는 경우)
        return .daytime
    }
}

class TimeSettingsStore: ObservableObject {
    @Published var settings: TimeSettings
    
    private let settingsKey = "timeSettings"
    
    init() {
        // App Group에서 먼저 시도
        let appGroupIdentifier = "group.com.jieun.Jiny-TODO"
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let data = sharedDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(TimeSettings.self, from: data) {
            self.settings = decoded
        } else if let data = UserDefaults.standard.data(forKey: settingsKey),
                  let decoded = try? JSONDecoder().decode(TimeSettings.self, from: data) {
            // 하위 호환성: standard에서 로드
            self.settings = decoded
        } else {
            self.settings = TimeSettings.defaultSettings
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            // App Group을 사용하여 위젯과 데이터 공유
            let appGroupIdentifier = "group.com.jieun.Jiny-TODO"
            if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                sharedDefaults.set(encoded, forKey: settingsKey)
            }
            // 하위 호환성을 위해 standard에도 저장
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
}


