import Carbon.HIToolbox
import CoreGraphics

enum KeyMonitorError: Error, CustomStringConvertible {
    case failedToCreateTap
    case failedToCreateSource

    var description: String {
        switch self {
        case .failedToCreateTap:
            "알 수 없는 오류가 발생했습니다. (key tap)"
        case .failedToCreateSource:
            "알 수 없는 오류가 발생했습니다. (key source)"
        }
    }
}

/**
 전역 키 조합 모니터링
 Shift+ESC -> ~, Cmd+ESC -> `, Cmd+\ -> ₩
 입력기 상태와 무관하게 시스템 전역으로 동작
 */
class KeyMonitor {
    /** 합성 이벤트 식별용 마커 */
    static let syntheticMarker: Int64 = 0x534F4B494D // "SOKIM"

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() throws {
        debug()

        if tap != nil || source != nil {
            warning("초기화된 tap 또는 source가 이미 있음")
            return
        }

        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, userInfo in
                // Tap이 비활성화된 경우 재활성화
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let userInfo {
                        let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                        if let tap = monitor.tap {
                            CGEvent.tapEnable(tap: tap, enable: true)
                        }
                    }
                    return Unmanaged.passUnretained(event)
                }

                guard type == .keyDown else {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                let hasShift = flags.contains(.maskShift)
                let hasCmd = flags.contains(.maskCommand)
                let hasOption = flags.contains(.maskAlternate)
                let hasControl = flags.contains(.maskControl)

                var char: String?

                // Shift + ESC -> ~
                if keyCode == Int64(kVK_Escape)
                    && hasShift && !hasCmd && !hasOption && !hasControl {
                    char = "~"
                }
                // Cmd + ESC -> `
                else if keyCode == Int64(kVK_Escape)
                    && hasCmd && !hasShift && !hasOption && !hasControl {
                    char = "`"
                }
                // Cmd + \ -> ₩
                else if keyCode == Int64(kVK_ANSI_Backslash)
                    && hasCmd && !hasShift && !hasOption && !hasControl {
                    char = "₩"
                }

                guard let char else {
                    return Unmanaged.passUnretained(event)
                }

                debug("키 조합 감지: \(char)")

                // 조합 중인 한글 확정
                appDelegate()?.commit()

                // 합성 이벤트 생성 및 전송 (cgSessionEventTap으로 전송하여 이 tap을 다시 거치지 않도록 함)
                guard let newEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) else {
                    return Unmanaged.passUnretained(event)
                }
                let utf16 = Array(char.utf16)
                newEvent.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                newEvent.flags = CGEventFlags(rawValue: 0)
                newEvent.setIntegerValueField(.eventSourceUserData, value: KeyMonitor.syntheticMarker)
                newEvent.post(tap: .cgSessionEventTap)

                // 원래 이벤트 억제
                return nil
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            warning("CGEvent.tapCreate 실패")
            throw KeyMonitorError.failedToCreateTap
        }
        self.tap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        guard let source else {
            warning("CFMachPortCreateRunLoopSource 실패")
            throw KeyMonitorError.failedToCreateSource
        }
        self.source = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        debug()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            self.tap = nil
        } else {
            notice("초기화된 tap이 없음")
        }

        if let source {
            CFRunLoopSourceInvalidate(source)
            self.source = nil
        } else {
            notice("초기화된 source가 없음")
        }
    }
}
