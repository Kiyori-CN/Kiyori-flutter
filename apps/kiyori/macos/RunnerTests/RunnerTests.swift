import Cocoa
import FlutterMacOS
import XCTest

class RunnerTests: XCTestCase {

  func testRunnerIdentity() {
    // 产品名同时用于 bundle、可执行文件和 XCTest 宿主，防止改名后测试加载错误目标。
    XCTAssertEqual(Bundle.main.bundleIdentifier, "com.kiyori.flutter")
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String, "Kiyori Flutter")
  }

}
