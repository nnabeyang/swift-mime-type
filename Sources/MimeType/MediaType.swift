import Foundation

private let utf8RuneSelf = 0x80
private let asciiSpace = [
    UInt8(ascii: "\t"): 1,
    UInt8(ascii: "\n"): 1,
    UInt8(ascii: "\u{b}"): 1,
    UInt8(ascii: "\u{c}"): 1,
    UInt8(ascii: "\r"): 1,
    UInt8(ascii: " "): 1,
]

public struct MediaType {
    public let type: String
    public let subType: String
    public let parameters: [String: String]
    public func serialize() -> String {
        return "\(type)/\(subType)\(parameters.map {"; \($0)=\($1)"}.joined(separator: ""))"
    }
}

private var mediaTypes: [String: MediaType] = [:]

enum MediaParamError: Error {
    case Invalid
    case duplicate
}

public func fileExtension(_ ext: String) -> MediaType? {
    return mediaTypes[ext]
}

func parseMediaType(_ v: String) -> Swift.Result<(String, [String: String]), MediaParamError> {
    let base: String = v.components(separatedBy: ";").first ?? v
    let mediaType = base.lowercased().trimmingCharacters(in: .whitespaces)
    var params: [String: String] = [:]
    var vv = ""
    if let i = v.firstIndex(of: ";") {
        vv = String(v[i..<v.endIndex])
    }
    while vv.count > 0 {
        vv = vv.trimmingCharacters(in: .whitespaces)
        if vv.count == 0 {
            break
        }
        let (key, value, rest) = consumeMediaParam(vv)
        if key == "" {
            if rest.trimmingCharacters(in: .whitespaces) == ";" {
                break
            }
            return .failure(.Invalid)
        }
        if params[key] != nil {
            return .failure(.duplicate)
        }
        params[key] = value
        vv = rest
    }
    return .success((mediaType, params))
}

func consumeMediaParam(_ v: String) -> (String, String, String) {
    var rest = v.trimmingCharacters(in: .whitespaces)
    if !rest.hasPrefix(";") {
        return ("", "", v)
    }

    rest = String(rest[rest.index(rest.startIndex, offsetBy: 1)..<rest.endIndex])
        .trimmingCharacters(in: .whitespaces)
    let (param, res) = consumeToken(rest)
    rest = res
    if param == "" {
        return ("", "", v)
    }
    if !rest.hasPrefix("=") {
        return ("", "", v)
    }
    rest = String(rest[rest.index(rest.startIndex, offsetBy: 1)..<rest.endIndex])
        .trimmingCharacters(in: .whitespaces)
    let (value, rest2) = consumeValue(rest)
    if value == "" && rest2 == rest {
        return ("", "", v)
    }

    return (param, value, rest2)
}

func consumeToken(_ v: String) -> (String, String) {
    guard let pos = v.firstIndex(where: isNotTokenChar) else {
        return (v, "")
    }
    if pos == v.startIndex {
        return ("", v)
    }
    return (String(v[v.startIndex..<pos]), String(v[pos..<v.endIndex]))
}

func consumeValue(_ v: String) -> (String, String) {
    if v == "" {
        return ("", "")
    }
    if v[v.startIndex] != "\"" {
        return consumeToken(v)
    }
    let a: [UInt8] = Array(v[v.index(v.startIndex, offsetBy: 1)..<v.endIndex].utf8)
    var data: Data = .init(capacity: a.count)
    var i = 0
    let n = a.count
    while i < n {
        let b = a[i]
        if b == UInt8(ascii: "\"") {
            return (String(data: data, encoding: .utf8)!, String(bytes: a[i + 1..<n], encoding: .utf8)!)
        }

        if b == UInt8(ascii: "\\") && i + 1 < n && isTSpecial(Character(Unicode.Scalar(b))) {
            i += 1
            data.append(a[i])
            continue
        }
        if b == UInt8(ascii: "\r") || b == UInt8(ascii: "\n") {
            return ("", v)
        }
        data.append(b)
        i += 1
    }

    return ("", "")
}

func isTSpecial(_ c: Character) -> Bool {
    return #"()<>@,;:\"/[]?="#.contains(c)
}

func isTokenChar(_ c: Character) -> Bool {
    guard let v = c.asciiValue else {
        return false
    }
    return v > 0x20 && v < 0x7f && !isTSpecial(c)
}

func isNotTokenChar(_ c: Character) -> Bool {
    return !isTokenChar(c)
}

public func loadMimeFile(atPath filename: String) {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: filename, isDirectory: &isDir),
        isDir.boolValue == false
    else {
        return
    }
    let f = FileHandle(forReadingAtPath: filename)!
    defer {
        f.closeFile()
    }
    let scanner: Scanner = .init(f)
    while scanner.scan() {
        let fs = fields(scanner.value())
        if fs.count <= 1 || fs[0][fs[0].startIndex] == "#" {
            continue
        }
        let mimeType = fs[0]
        for ext in fs[1..<fs.count] {
            setExtensionType(ext, mimeType)
        }
    }
}

func setExtensionType(_ ext: String, _ mimeType: String) {
    let r = parseMediaType(mimeType)
    switch r {
    case .success(let (justType, ps)):
        var params: [String: String] = ps
        if justType.hasPrefix("text/") && params["charset"] == nil {
            params["charset"] = "utf-8"
        }
        let a = justType.split(separator: "/")
        if a.count != 2 {
            return
        }
        let type: MediaType = .init(type: String(a[0]), subType: String(a[1]), parameters: params)
        mediaTypes[ext] = type
    case .failure:
        return
    }
}

func fields(_ bs: [UInt8]) -> [String] {
    var n = 0  // number of fields
    var wasSpace = 1
    var setBits: UInt8 = 0
    let bn = bs.count
    for r in bs {
        setBits |= r
        let isSpace: Int = asciiSpace[r] ?? 0
        n += wasSpace & ~isSpace
        wasSpace = isSpace
    }

    assert(setBits < utf8RuneSelf, "input s is not ascii string.")

    var a: [String] = .init(repeating: "", count: n)
    var na = 0
    var fieldStart = 0
    var i = 0
    // skip spaces in the front of the input.
    while i < bn && asciiSpace[bs[i]] != nil {
        i += 1
    }
    fieldStart = i
    while i < bn {
        if asciiSpace[bs[i]] == nil {
            i += 1
            continue
        }
        a[na] = String(data: Data(bs[fieldStart..<i]), encoding: .utf8)!
        na += 1
        i += 1
        // skip spaces between fields.
        while i < bn && asciiSpace[bs[i]] != nil {
            i += 1
        }
        fieldStart = i
    }
    if fieldStart < bn {
        a[na] = String(data: Data(bs[fieldStart..<bn]), encoding: .utf8)!
    }
    return a
}
