import InputMethodKit

/**
 "이중 입력 수정" 화이트리스트.
 - 이 목록에 있는 번들 ID는 MarkedStrategy 대신 FixedMarkedStrategy를 사용.
 - 자동 감지 결과가 DirectStrategy면 이 목록과 무관하게 Direct 사용(이슈 무관).
 - 입력기 메뉴(`Controller.menu()`)에서 토글하거나 `defaults write com.kiding.inputmethod.sok useFixedMarkedBundleIDs -array <id> ...`.
 - 키가 미설정이면 빈 배열(빌드 직후 = 모든 앱이 기본 동작).
 */
let useFixedMarkedKey = "useFixedMarkedBundleIDs"

let defaultUseFixedMarked: [String] = []

/**
 hot path(`strategy(for:)`)에서 매번 UserDefaults를 읽지 않도록 메모리에 캐시.
 변경은 동일 프로세스 내(IME 메뉴)에서 일어나므로 `UserDefaults.didChangeNotification`만으로 즉시 반영됨.
 */
private var cachedUseFixedMarked: [String] = defaultUseFixedMarked

private func reloadStrategyCache() {
    let defaults = UserDefaults.standard
    cachedUseFixedMarked = defaults.stringArray(forKey: useFixedMarkedKey) ?? defaultUseFixedMarked
    debug("useFixedMarked: \(cachedUseFixedMarked)")
}

func setupStrategyCache() {
    reloadStrategyCache()
    NotificationCenter.default.addObserver(
        forName: UserDefaults.didChangeNotification,
        object: nil,
        queue: .main
    ) { _ in
        reloadStrategyCache()
    }
}

/** 메뉴에서 사용 */
func currentUseFixedMarkedList() -> [String] { cachedUseFixedMarked }

/**
 입력 방식 선택

 # `sender.validAttributesForMarkedText()`

 ## Direct

 | App | Attributes |
 |--|--|
 | Xcode | NSMarkedClauseSegment NSGlyphInfo ... |
 | Pages | ... NSFont NSMarkedClauseSegment ... |
 | Numbers | ... NSFont NSMarkedClauseSegment ... |
 | Keynote | ... NSFont NSMarkedClauseSegment ... |
 | Word | NSFont ... NSMarkedClauseSegment ... |
 | PowerPoint | NSFont ... NSMarkedClauseSegment ... |
 | TextEdit | NSFont ... NSMarkedClauseSegment ... NSGlyphInfo NSTextAlternatives ... |
 | Stickies | NSFont ... NSMarkedClauseSegment ... NSGlyphInfo NSTextAlternatives ... |
 | Tweetbot | NSFont ... NSMarkedClauseSegment ... NSTextAlternatives ... |
 | Paw | NSFont ... NSMarkedClauseSegment ... NSTextAlternatives ... |
 | Safari | ... NSMarkedClauseSegment NSTextAlternatives ... |
 | DuckDuckGo | ... NSMarkedClauseSegment NSTextAlternatives ... |
 | Overcast | ... NSMarkedClauseSegment NSTextAlternatives ... |

 ## Marked

 | App | Attributes |
 |--|--|
 | GIMP | ... |
 | Sublime Text | ... |
 | Alacritty | ... |
 | Android Studio | ... |
 | iTerm2 | ... NSFont ... |
 | Terminal | ... |
 | LINE | ... |
 | VS Code | ... NSMarkedClauseSegment ... |
 | Chrome | ... NSMarkedClauseSegment ... |
 | Firefox | ... NSMarkedClauseSegment ... |
 | Slack | ... NSMarkedClauseSegment ... |
 | Excel | ... |
 */
/** sender의 `validAttributesForMarkedText()`만 보고 결정하는 자동 감지(강제 오버라이드 미적용). 메뉴에서 미리보기로도 사용. */
func autoDetectStrategy(for sender: IMKTextInput) -> Strategy.Type {
    let attributes = sender.validAttributesForMarkedText() as? [String] ?? []
    debug("validAttributesForMarkedText: \(attributes)")

    if attributes.contains("NSTextAlternatives")
        || attributes.contains("NSMarkedClauseSegment") && attributes.contains("NSFont")
        || attributes.contains("NSMarkedClauseSegment") && attributes.contains("NSGlyphInfo") {
        return DirectStrategy.self
    } else {
        return MarkedStrategy.self
    }
}

func strategy(for sender: IMKTextInput) -> Strategy.Type {
    debug()

    let auto = autoDetectStrategy(for: sender)

    // Direct 자동 감지 결과면 그대로 사용 (이중 입력 이슈 무관)
    if auto == DirectStrategy.self {
        return DirectStrategy.self
    }

    // Marked인데 화이트리스트에 있으면 FixedMarkedStrategy로 교체
    if let bundleIdentifier = sender.bundleIdentifier(),
       cachedUseFixedMarked.contains(bundleIdentifier) {
        return FixedMarkedStrategy.self
    }

    return MarkedStrategy.self
}

/** 입력 방식 */
protocol Strategy {
    /** 백스페이스 처리된 state를 sender에 입력. 완료 후 sender가 추가 처리해야 하면 false, 필요하지 않으면 true 반환 */
    static func backspace(from state: State, to sender: IMKTextInput, with composing: String) -> Bool

    /** 조합 지속을 목적으로 state에 저장된 문자열을 sender에 입력, 실패하면 false 반환 */
    static func next(from state: State, to sender: IMKTextInput, with composing: String) -> Bool

    /** 조합 종료를 목적으로 state에 저장된 문자열을 sender에 입력 */
    static func commit(from state: State, to sender: IMKTextInput)
}
