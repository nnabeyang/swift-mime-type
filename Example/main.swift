import Foundation.NSBundle
import MimeType

let url = Bundle.module.url(forResource: "mime", withExtension: "types")!
loadMimeFile(atPath: url.path)
print(fileExtension("html")!.serialize())
