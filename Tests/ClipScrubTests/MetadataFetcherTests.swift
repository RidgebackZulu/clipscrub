import XCTest
@testable import ClipScrub

final class MetadataFetcherTests: XCTestCase {

    // MARK: - OG Tag Parsing

    func testParsesStandardOGTags() {
        let html = """
        <html><head>
        <meta property="og:title" content="My Page Title">
        <meta property="og:description" content="A description of the page">
        <meta property="og:image" content="https://example.com/image.jpg">
        </head></html>
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "My Page Title")
        XCTAssertEqual(tags["description"], "A description of the page")
        XCTAssertEqual(tags["image"], "https://example.com/image.jpg")
    }

    func testParsesReversedAttributeOrder() {
        let html = """
        <meta content="Reversed Title" property="og:title">
        <meta content="Reversed Desc" property="og:description">
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "Reversed Title")
        XCTAssertEqual(tags["description"], "Reversed Desc")
    }

    func testParsesSingleQuotes() {
        let html = """
        <meta property='og:title' content='Single Quoted Title'>
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "Single Quoted Title")
    }

    func testParsesSelfClosingTags() {
        let html = """
        <meta property="og:title" content="Self Closing" />
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "Self Closing")
    }

    func testReturnsEmptyForNoOGTags() {
        let html = "<html><head><title>Plain</title></head></html>"
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertTrue(tags.isEmpty)
    }

    func testFirstOccurrenceWins() {
        let html = """
        <meta property="og:title" content="First Title">
        <meta property="og:title" content="Second Title">
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "First Title")
    }

    func testCaseInsensitivePropertyMatch() {
        let html = """
        <META PROPERTY="og:title" CONTENT="Uppercase Tags">
        """
        let tags = MetadataFetcher.parseOGTags(from: html)
        XCTAssertEqual(tags["title"], "Uppercase Tags")
    }

    // MARK: - HTML Title Fallback

    func testParsesHTMLTitle() {
        let html = "<html><head><title>Fallback Title</title></head></html>"
        let title = MetadataFetcher.parseHTMLTitle(from: html)
        XCTAssertEqual(title, "Fallback Title")
    }

    func testReturnsNilForMissingTitle() {
        let html = "<html><head></head></html>"
        let title = MetadataFetcher.parseHTMLTitle(from: html)
        XCTAssertNil(title)
    }

    func testTrimsWhitespaceInTitle() {
        let html = "<title>  Spaced Title  \n</title>"
        let title = MetadataFetcher.parseHTMLTitle(from: html)
        XCTAssertEqual(title, "Spaced Title")
    }

    func testDecodesHTMLEntitiesInTitle() {
        let html = "<title>Tom &amp; Jerry&#39;s Show</title>"
        let title = MetadataFetcher.parseHTMLTitle(from: html)
        XCTAssertEqual(title, "Tom & Jerry's Show")
    }

    // MARK: - Twitter Meta Tags

    func testParsesTwitterTags() {
        let html = """
        <meta name="twitter:title" content="Tweet Title">
        <meta name="twitter:description" content="Tweet description here">
        <meta name="twitter:image" content="https://pbs.twimg.com/media/abc.jpg">
        """
        let tags = MetadataFetcher.parseTwitterTags(from: html)
        XCTAssertEqual(tags["title"], "Tweet Title")
        XCTAssertEqual(tags["description"], "Tweet description here")
        XCTAssertEqual(tags["image"], "https://pbs.twimg.com/media/abc.jpg")
    }

    func testParsesTwitterTagsReversedOrder() {
        let html = """
        <meta content="Reversed Twitter" name="twitter:title">
        """
        let tags = MetadataFetcher.parseTwitterTags(from: html)
        XCTAssertEqual(tags["title"], "Reversed Twitter")
    }

    func testTwitterTagsReturnEmptyForNoTags() {
        let html = "<html><head><title>Plain</title></head></html>"
        let tags = MetadataFetcher.parseTwitterTags(from: html)
        XCTAssertTrue(tags.isEmpty)
    }
}
