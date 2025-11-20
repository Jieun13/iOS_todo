# 위젯 설정 가이드

## 위젯 사이즈

iOS 위젯은 다음과 같은 사이즈를 지원합니다:

- **Small (소형)**: 2x2 (약 155x155 points)
  - 최대 3개의 할 일 표시
  - 현재 시간대와 할 일 개수 표시

- **Medium (중형)**: 4x2 (약 329x155 points)
  - 최대 4개의 할 일 표시
  - 왼쪽에 시간대 정보, 오른쪽에 할 일 목록

- **Large (대형)**: 4x4 (약 329x345 points)
  - 최대 5개의 할 일 표시
  - 더 많은 정보를 표시할 수 있는 공간

## Xcode에서 위젯 추가하기

### 1. Widget Extension 타겟 추가

1. Xcode에서 프로젝트를 엽니다
2. 상단 메뉴에서 **File > New > Target...** 선택
3. **Widget Extension** 선택 후 **Next** 클릭
4. 다음 정보 입력:
   - **Product Name**: `myTodoAPPWidget`
   - **Organization Identifier**: 기존 앱과 동일하게 설정
   - **Bundle Identifier**: 자동 생성됨
   - **Language**: Swift
   - **Include Configuration Intent**: 체크 해제 (Static Configuration 사용)
5. **Finish** 클릭

### 2. 기존 위젯 파일로 교체

위젯 Extension이 생성되면 기본 파일들이 생성됩니다. 다음 파일들을 교체하세요:

- `myTodoAPPWidget.swift` → `Widget/TodoWidget.swift`의 내용으로 교체
- `myTodoAPPWidgetBundle.swift` (있다면) → 삭제하고 `TodoWidget.swift`만 사용

또는 생성된 위젯 Extension 폴더에 다음 파일들을 복사:

- `TodoWidget.swift`
- `TodoWidgetProvider.swift`
- `TodoWidgetView.swift`

### 3. 파일 참조 추가

위젯 Extension 타겟에서 다음 파일들을 참조에 추가해야 합니다:

- `Models/TodoItem.swift`
- `Models/TimeSettings.swift`
- `Views/MainViewHelper.swift`

**방법:**
1. 프로젝트 네비게이터에서 파일 선택
2. File Inspector (오른쪽 패널) 열기
3. **Target Membership**에서 위젯 Extension 타겟 체크

### 4. 빌드 및 실행

1. 위젯 Extension 타겟 선택
2. 시뮬레이터 또는 실제 기기에서 실행
3. 홈 화면에서 위젯 추가:
   - 홈 화면 길게 누르기
   - 왼쪽 상단의 **+** 버튼 클릭
   - "할 일" 위젯 검색 후 추가

## 위젯 기능

- **자동 업데이트**: 15분마다 자동으로 업데이트됩니다
- **현재 시간대 표시**: 현재 시간대(아침, 일과 중, 귀가 후, 자기 전)의 할 일만 표시
- **상태 표시**: 미완료, 진행중, 완료 상태를 아이콘으로 표시
- **정렬**: 진행중 > 미완료 > 완료 순서로 정렬

## 데이터 공유

현재 위젯은 `UserDefaults.standard`를 사용하여 메인 앱과 데이터를 공유합니다.

향후 App Group을 사용하여 더 안정적인 데이터 공유를 원한다면:

1. **App Group 설정**:
   - 메인 앱과 위젯 Extension 모두에 동일한 App Group 추가
   - 예: `group.com.jieun.Jiny-TODO`

2. **UserDefaults 변경**:
   - `UserDefaults.standard` → `UserDefaults(suiteName: "group.com.jieun.Jiny-TODO")`

## 문제 해결

### 위젯이 데이터를 표시하지 않는 경우

1. 메인 앱에서 할 일을 생성했는지 확인
2. 현재 시간대에 할 일이 있는지 확인
3. 위젯을 길게 눌러 **위젯 편집**에서 새로고침

### 빌드 오류가 발생하는 경우

1. 위젯 Extension 타겟에 필요한 파일들이 모두 포함되어 있는지 확인
2. `@main` 어노테이션이 `TodoWidget`에만 있는지 확인 (중복 제거)
3. 위젯 Extension의 Deployment Target이 메인 앱과 동일한지 확인

