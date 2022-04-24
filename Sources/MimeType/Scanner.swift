import Foundation

protocol Reader {
    func read(_ n: Int) -> Swift.Result<[UInt8], IOError>
}
enum IOError: Swift.Error {
    case eof
    case badReadCount
    case noProgress
}
extension FileHandle: Reader {
    func read(_ n: Int) -> Swift.Result<[UInt8], IOError> {
        let data: Data = self.readData(ofLength: n)
        if data.count == 0 {
            return .failure(.eof)
        }
        return .success(Array(data))
    }
}

extension Data {
    var bytes: [UInt8] {
        return self.withUnsafeBytes { pointer -> [UInt8] in
            guard
                let address =
                    pointer
                    .bindMemory(to: UInt8.self)
                    .baseAddress
            else { return [] }
            return [UInt8](UnsafeBufferPointer(start: address, count: self.count))
        }
    }
}

func scanLines(data: [UInt8], atEOF: Bool) -> Swift.Result<(Int, [UInt8]), Error> {
    if atEOF && data.count == 0 {
        return .success((0, []))
    }

    let i = indexByte(data, UInt8(ascii: "\n"))
    if i >= 0 {
        return .success((i + 1, dropCR(Array(data[0..<i]))))
    }

    if atEOF {
        return .success((data.count, dropCR(data)))
    }

    return .success((0, []))
}

func dropCR(_ data: [UInt8]) -> [UInt8] {
    let n = data.count
    if n > 0 && data[n - 1] == UInt8(ascii: "\r") {
        return [UInt8](data[0..<n])
    }
    return [UInt8](data)
}

func indexByte(_ b: [UInt8], _ c: UInt8) -> Int {
    return b.firstIndex(of: c) ?? -1
}

private let maxScanTokenSize = 64 * 1024
private let startBufSize = 4096
private let maxConsecutiveEmptyReads = 100
final class Scanner {

    typealias SplitFunc = ([UInt8], Bool) -> Swift.Result<(Int, [UInt8]), Error>

    private let r: Reader
    private let split: SplitFunc
    private let maxTokenSize: Int
    private var token: [UInt8] = []
    private var buf: [UInt8] = []
    private var start: Int = 0
    private var end: Int = 0
    private var error: Error? = nil

    init(
        _ r: Reader,
        split: @escaping SplitFunc = scanLines,
        maxTokenSize: Int = maxScanTokenSize
    ) {
        self.r = r
        self.split = split
        self.maxTokenSize = maxScanTokenSize
    }

    func value() -> [UInt8] {
        return token
    }

    func scan() -> Bool {
        while true {
            if end > start || self.error != nil {
                let r = split(Array(buf[start..<end]), self.error != nil)
                switch r {
                case .success(let (n, token)):
                    if !advance(n) {
                        return false
                    }
                    self.token = token
                    if n > 0 {
                        return true
                    }
                case .failure(let error):
                    self.error = error
                    return false
                }
            }

            if self.error != nil {
                start = 0
                end = 0
                return false
            }

            if end == buf.count {
                let newSize = startBufSize > maxTokenSize ? maxTokenSize : startBufSize
                var newBuf: [UInt8] = [UInt8](repeating: 0, count: newSize)
                newBuf[0..<(end - start)] = buf[0..<buf.count]
                buf = newBuf
                end -= start
                start = 0
            }

            var loop = 0
            readFile: while true {
                let n = buf.count - end
                let r = r.read(n)
                switch r {
                case .success(let data):
                    if n < data.count {
                        error = IOError.badReadCount
                        break readFile
                    }
                    buf[end..<(end + data.count)] = data[0..<data.count]
                    end += data.count
                    if n > 0 {
                        break readFile
                    }
                    loop += 1
                    if loop > maxConsecutiveEmptyReads {
                        self.error = IOError.noProgress
                        break readFile
                    }
                case .failure(let error):
                    self.error = error
                    break readFile
                }
            }
        }
    }

    private func advance(_ n: Int) -> Bool {
        start += n
        return true
    }
}
