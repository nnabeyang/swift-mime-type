import XCTest

@testable import MimeType

final class MimeTypeTests: XCTestCase {
    func xtestParseMediaType() throws {
        let r = parseMediaType("text/html ; charset=utf-8")
        if case .success(let (v, params)) = r {
            XCTAssertEqual(v, "text/html")
            XCTAssertEqual(params, [:])
            return
        }
        XCTFail()
    }

    func testParseMediaParam() throws {
        let line = #"multipart/form-data; boundary=something"#
        let r = parseMediaType(line)
        if case .success(let (mediaType, params)) = r {
            XCTAssertEqual(mediaType, "multipart/form-data")
            XCTAssertEqual(params, ["boundary": "something"])
            return
        }
        XCTFail()
    }

    func testParseMediaParam2() throws {
        let line = #"application/andrew-inset"#
        let r = parseMediaType(line)
        if case .success(let (mediaType, params)) = r {
            XCTAssertEqual(mediaType, "application/andrew-inset")
            XCTAssertEqual(params, [:])
            return
        }
        XCTFail()
    }

    func testMediaTypeSerialize() throws {
        let t = MediaType(type: "text", subType: "html", parameters: ["charset": "utf-8"])
        XCTAssertEqual(t.serialize(), "text/html; charset=utf-8")
    }
}
