# 로직 설명 문서

이 문서는 myTodoAPP의 주요 로직과 동작 방식을 설명합니다.

## 목차
1. [할 일 데이터 모델](#할-일-데이터-모델)
2. [시간대 범위 계산](#시간대-범위-계산)
3. [Calendar & Reminders 동기화](#calendar--reminders-동기화)
4. [할 일 필터링 및 정렬](#할-일-필터링-및-정렬)
5. [시간대 이동 로직](#시간대-이동-로직)

---

## 할 일 데이터 모델

### TodoItem 구조

```swift
struct TodoItem {
    let id: UUID
    var title: String
    var memo: String?
    var type: TodoType              // "해야 할 일" 또는 "하고 싶은 일"
    var timeCategory: TimeCategory? // 아침, 일과 중, 귀가 후, 자기 전
    var status: TodoStatus          // 미완료, 진행중, 완료
    var startTime: Date?            // 할 일 시작 시간 (캘린더/미리알림에서 가져온 경우에만 설정)
    var completedAt: Date?
    var reminderIdentifier: String? // 미리알림과의 연결을 위한 식별자
    var calendarEventIdentifier: String? // 캘린더 이벤트와의 연결을 위한 식별자
}
```

### 할 일 구분 방법

1. **앱에서 생성한 할 일**
   - `startTime == nil`
   - `reminderIdentifier`는 있을 수 있지만 시간 정보는 없음
   - Reminders에 날짜만 설정되어 생성됨

2. **Calendar에서 가져온 할 일**
   - `startTime != nil`
   - `calendarEventIdentifier != nil`
   - Calendar 이벤트의 시작 시간을 `startTime`으로 사용

3. **Reminders에서 가져온 할 일**
   - `startTime != nil` (시간 정보가 있는 경우)
   - `reminderIdentifier != nil`
   - Reminder의 dueDate를 `startTime`으로 사용

---

## 시간대 범위 계산

### 하루 범위 정의

하루 범위는 **아침 시작 시간부터 다음날 아침 시작 시간 전까지**입니다.

- **일반 시간대** (아침 시작 ~ 다음날 아침 시작 전):
  - `dayRangeStart` = 오늘 아침 시작 시간
  - `dayRangeEnd` = 내일 아침 시작 시간

- **새벽 시간대** (0시 ~ 아침 시작 전):
  - `dayRangeStart` = 어제 아침 시작 시간
  - `dayRangeEnd` = 오늘 아침 시작 시간

### 시간대별 범위

각 시간대는 설정 가능한 시작/종료 시간을 가집니다:
- **아침**: `morningStart` ~ `morningEnd`
- **일과 중**: `daytimeStart` ~ `daytimeEnd`
- **귀가 후**: `eveningStart` ~ `eveningEnd`
- **자기 전**: `nightStart` ~ `nightEnd`

---

## Calendar & Reminders 동기화

### 동기화 전략

1. **앞뒤 2일치 가져오기**
   - `fetchStartDate` = `dayRangeStart - 2일`
   - `fetchEndDate` = `dayRangeEnd + 2일`
   - 넓은 범위로 가져온 후 필터링하여 누락 방지

2. **기존 항목 업데이트**
   - 식별자(`reminderIdentifier` 또는 `calendarEventIdentifier`)로 기존 항목 찾기
   - 범위와 관계없이 항상 업데이트 (외부에서 이동한 경우 대비)

3. **새 항목 추가**
   - 하루 범위(`dayRangeStart` ~ `dayRangeEnd`) 내에 있는 경우만 추가
   - 날짜만 있는 미리알림의 경우: `dayRangeStart`의 날짜부터 `dayRangeEnd`의 날짜 전날까지 포함

4. **삭제된 항목 제거**
   - 가져온 항목 목록에 없는 식별자는 삭제된 것으로 간주
   - 식별자로 직접 접근하여 확인 후 앱에서 제거

### CalendarEventSync 로직

```swift
1. 앞뒤 2일치 이벤트 가져오기
2. 각 이벤트에 대해:
   - 기존 항목이 있으면 → 업데이트 (범위 무관)
   - 새 이벤트이고 하루 범위 내에 있으면 → 추가
3. 앱에 있지만 가져온 목록에 없는 이벤트:
   - 식별자로 직접 접근
   - 삭제되었거나 범위 밖으로 이동했으면 → 앱에서 제거
```

### ReminderSync 로직

```swift
1. 모든 미리알림 가져오기 (EventKit 제약으로 시간 범위 필터 불가)
2. 각 미리알림에 대해:
   - 앱에서 생성한 미리알림 (startTime == nil):
     → 제목/메모만 업데이트
   - 기존 항목이 있으면 → 업데이트 (범위 무관)
   - 새 미리알림이고:
     * 날짜만 있는 경우: dayRangeStart 날짜 ~ dayRangeEnd 날짜 전날까지
     * 시간이 있는 경우: dayRangeStart ~ dayRangeEnd 시간 범위 내
     → 하루 범위 내에 있으면 추가
3. 앱에 있지만 가져온 목록에 없는 미리알림:
   - 식별자로 직접 접근
   - 삭제되었거나 범위 밖으로 이동했으면 → 앱에서 제거
```

### 동기화 시점

- 앱 시작 시
- 앱이 포그라운드로 돌아올 때
- 설정 화면에서 수동 동기화 시

---

## 할 일 필터링 및 정렬

### 필터링 로직

```swift
// 하루 범위 내 할 일 필터링
if let startTime = todo.startTime {
    // 시간이 있는 할 일: 시간 범위로 필터링
    timeInRange = startTime >= dayRangeStart && startTime < dayRangeEnd
} else {
    // 앱에서 생성한 할 일: 항상 포함
    timeInRange = true
}
```

### 정렬 로직

1. `startTime`이 있는 경우: `startTime` 기준 오름차순
2. `startTime`이 없는 경우: `id` 기준 (생성 순서)

---

## 시간대 이동 로직

### moveTodoToNextTimeCategory / moveTodoToPreviousTimeCategory

```swift
1. 현재 시간대 확인
2. 다음/이전 시간대로 변경
3. 미리알림과 연동된 할 일 (startTime != nil && reminderIdentifier != nil):
   - startTime 제거
   - Reminders에서 시간 정보 제거 (날짜만 유지)
4. 앱에서 생성한 할 일 (startTime == nil):
   - 시간대만 변경
```

### 스와이프 제스처

- 할 일 행을 왼쪽으로 스와이프하면 시간대 이동 버튼 표시
- 완료된 할 일은 스와이프 불가
- 버튼 클릭 시 시간대 이동 후 스와이프 닫기

---

## 데이터 저장

### UserDefaults 사용

- `TodoItem` 배열: JSON으로 인코딩하여 저장
- `TimeSettings`: JSON으로 인코딩하여 저장
- 앱 종료 후에도 데이터 유지

### 마이그레이션

- `createdAt` → `startTime` 마이그레이션 지원
- 하위 호환성을 위한 `CodingKeys` 사용

---

## 주요 고려사항

### 1. 시간대 처리
- 자정을 넘어가는 시간대 (예: 자기 전 22시 ~ 아침 6시) 처리
- 새벽 시간대의 하루 범위 계산

### 2. 동기화 충돌 방지
- 식별자 기반 매칭으로 중복 방지
- 직접 접근(`eventStore.event(withIdentifier:)`)으로 효율성 향상

### 3. 성능 최적화
- 앞뒤 2일치만 가져와서 필터링
- 기존 항목은 범위 무관 업데이트로 누락 방지
- DispatchGroup으로 비동기 처리

### 4. 사용자 경험
- 앱에서 생성한 할 일은 시간 없이 Reminders에 추가
- 외부에서 수정한 내용 자동 반영
- 스와이프 제스처로 직관적인 시간대 이동

