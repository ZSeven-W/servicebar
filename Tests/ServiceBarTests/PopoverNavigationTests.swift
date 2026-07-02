import XCTest
@testable import ServiceBar

final class PopoverNavigationTests: XCTestCase {
    func testClosePopoverNotificationNameIsStable() {
        XCTAssertEqual(Notification.Name.closePopover.rawValue, "ClosePopover")
    }
}
