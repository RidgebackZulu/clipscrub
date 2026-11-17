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

    func testStripsNewXShareParameter() {
        XCTAssertEqual(URLSanitizer.sanitize("https://x.com/BNONews/status/2122531821275517355?a=V6GaIWdbKeXiq0OUC_s"),
                       "https://x.com/BNONews/status/2122531821275517355")
    }

    func testXShareParameterPreservesOtherQueryAndFragment() {
        XCTAssertEqual(URLSanitizer.sanitize("https://mobile.x.com/user/status/123?a=one&a=two&id=42#photo"),
                       "https://mobile.x.com/user/status/123?id=42#photo")
    }

    func testShareParameterIsDomainScoped() {
        for host in ["example.com", "notx.com", "x.com.example.com"] {
            XCTAssertNil(URLSanitizer.sanitize("https://\(host)/?a=keep"))
        }
    }

    func testPreservesAmbiguousParametersOutsideTheirServices() {
        for host in ["example.com", "youtube.com.example.com", "notreddit.com", "google.co.uk.example.com", "notgoogle.co.uk"] {
            let url = "https://\(host)/?source=account&feature=export&ref=document&si=42&ei=7&_t=version&trackingid=order&ocid=item"
            XCTAssertNil(URLSanitizer.sanitize(url))
            XCTAssertEqual(URLSanitizer.sanitize(url + "&utm_source=test"), url)
        }
    }

    func testServiceSpecificParametersStillRemoved() {
        for (host, query) in [
            ("www.google.com", "source=share&ei=1&ved=2"),
            ("www.google.co.uk", "source=share&ei=1&ved=2"),
            ("www.google.com.au", "source=share&ei=1&ved=2"),
            ("www.youtube.com", "feature=share&si=1&pp=2"),
            ("youtu.be", "si=1"),
            ("www.reddit.com", "ref=share&ref_source=link"),
            ("vm.tiktok.com", "_t=1&_r=2"),
            ("www.linkedin.com", "trackingId=1&trk=2"),
            ("www.msn.com", "ocid=1&cvid=2")
        ] {
            XCTAssertEqual(URLSanitizer.sanitize("https://\(host)/?\(query)&id=keep"),
                           "https://\(host)/?id=keep")
        }
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
