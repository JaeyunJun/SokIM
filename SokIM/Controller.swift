import InputMethodKit
import AppKit

/**
 @see Info.plist
 */
@objc(Controller)
class Controller: IMKInputController {
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        debug("\(String(describing: event)) \(String(describing: sender))")

        return appDelegate()?.handle(event, client: sender) ?? false
    }

    /**
     입력기 메뉴: 현재 frontmost 앱의 마지막 글자 처리 방식을 두 가지 중 선택.
     - 기본: MarkedStrategy.commit()이 composing을 insertText로 재삽입 (이중 입력 발생 가능)
     - 수정: FixedMarkedStrategy.commit()이 OS 자동 확정에 위임 (이중 입력 방지, 일부 앱에선 글자 손실 가능)
     */
    override func menu() -> NSMenu! {
        let menu = NSMenu()

        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier ?? ""
        let appName = frontApp?.localizedName ?? bundleID

        if bundleID.isEmpty || bundleID == Bundle.main.bundleIdentifier {
            let item = NSMenuItem(title: "현재 앱을 감지할 수 없음", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        // 헤더
        let header = NSMenuItem(title: "현재 앱: \(appName)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let subHeader = NSMenuItem(title: "    \(bundleID)", action: nil, keyEquivalent: "")
        subHeader.isEnabled = false
        menu.addItem(subHeader)

        menu.addItem(.separator())

        let isFixed = currentUseFixedMarkedList().contains(bundleID)

        let original = NSMenuItem(title: "기본 (이중 입력 발생 가능)",
                                  action: #selector(setOriginal(_:)),
                                  keyEquivalent: "")
        original.target = self
        original.representedObject = bundleID
        original.state = isFixed ? .off : .on
        menu.addItem(original)

        let fixed = NSMenuItem(title: "수정 (이중 입력 방지)",
                               action: #selector(setFixed(_:)),
                               keyEquivalent: "")
        fixed.target = self
        fixed.representedObject = bundleID
        fixed.state = isFixed ? .on : .off
        menu.addItem(fixed)

        return menu
    }

    /**
     IMK 메뉴 액션의 sender는 NSMenuItem이 아니라 `["IMKCommandMenuItem": NSMenuItem]` Dictionary.
     공식 문서엔 없고 NavilIME 등에서 발견한 IMK 내부 동작.
     */
    private func extractMenuItem(_ sender: Any?) -> NSMenuItem? {
        if let dict = sender as? [String: Any] {
            return dict["IMKCommandMenuItem"] as? NSMenuItem
        }
        return sender as? NSMenuItem
    }

    @objc private func setOriginal(_ sender: Any?) {
        guard let bundleID = extractMenuItem(sender)?.representedObject as? String else { return }
        var list = currentUseFixedMarkedList()
        list.removeAll { $0 == bundleID }
        UserDefaults.standard.set(list, forKey: useFixedMarkedKey)
    }

    @objc private func setFixed(_ sender: Any?) {
        guard let bundleID = extractMenuItem(sender)?.representedObject as? String else { return }
        var list = currentUseFixedMarkedList()
        if !list.contains(bundleID) { list.append(bundleID) }
        UserDefaults.standard.set(list, forKey: useFixedMarkedKey)
    }
}
