import XCTest
@testable import ClipScrub

final class URLSanitizerTests: XCTestCase {

    func testStripsUTMParams() {
        let input = "https://example.com/page?utm_source=twitter&utm_medium=social&utm_campaign=launch"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/page")
    }

    func testPreservesNonTrackingParams() {
        let input = "https://youtube.com/watch?v=dQw4w9WgXcQ&si=abc123"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://youtube.com/watch?v=dQw4w9WgXcQ")
    }

    func testStripsInstagramParams() {
        let input = "https://www.instagram.com/reel/abc123/?igsh=xyz&utm_source=ig_web_copy_link"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://www.instagram.com/reel/abc123/")
    }

    func testStripsTwitterDomainScopedParams() {
        let input = "https://x.com/user/status/123?s=20&t=abcdef"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://x.com/user/status/123")
    }

    func testDoesNotStripGenericSOnOtherDomains() {
        let input = "https://example.com/search?s=hello&utm_source=test"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/search?s=hello")
    }

    func testReturnsNilWhenNoChanges() {
        let input = "https://example.com/page?id=42&name=test"
        let result = URLSanitizer.sanitize(input)
        XCTAssertNil(result)
    }

    func testReturnsNilForNoQueryParams() {
        let input = "https://example.com/page"
        let result = URLSanitizer.sanitize(input)
        XCTAssertNil(result)
    }

    func testRemovesQuestionMarkWhenAllParamsStripped() {
        let input = "https://example.com/page?fbclid=abc123"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/page")
        XCTAssertFalse(result!.contains("?"))
    }

    func testStripsFacebookParams() {
        let input = "https://example.com/?fbclid=abc&fb_action_ids=1&fb_ref=nf"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/")
    }

    func testStripsGoogleParams() {
        let input = "https://www.google.com/search?q=swift&gclid=abc&sxsrf=xyz&ved=123"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://www.google.com/search?q=swift")
    }

    func testCaseInsensitiveParamMatching() {
        let input = "https://example.com/?UTM_SOURCE=test&UTM_MEDIUM=email"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/")
    }

    func testPreservesFragment() {
        let input = "https://example.com/page?utm_source=test#section-2"
        let result = URLSanitizer.sanitize(input)
        XCTAssertEqual(result, "https://example.com/page#section-2")
    }

    // MARK: - isURL tests

    func testIsURLWithHTTPS() {
        XCTAssertTrue(URLSanitizer.isURL("https://example.com"))
    }

    func testIsURLWithHTTP() {
        XCTAssertTrue(URLSanitizer.isURL("http://example.com"))
    }

    func testIsURLWithShortDomain() {
        XCTAssertTrue(URLSanitizer.isURL("t.co/abc123"))
        XCTAssertTrue(URLSanitizer.isURL("bit.ly/xyz"))
        XCTAssertTrue(URLSanitizer.isURL("youtu.be/dQw4w9WgXcQ"))
    }

    func testIsURLPlainText() {
        XCTAssertFalse(URLSanitizer.isURL("hello world"))
        XCTAssertFalse(URLSanitizer.isURL("just some text"))
    }

    func testIsURLTrimsWhitespace() {
        XCTAssertTrue(URLSanitizer.isURL("  https://example.com  \n"))
    }
}
