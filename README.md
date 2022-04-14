# swift-media-type

A swift port of mime package in go.
this library provides a function which detects appropriate MIME type for a given file extension.

## Usage

```swift
import MimeType

loadMimeFile(atPath: "/etc/apache2/mime.types")
print(fileExtension("html")?.serialize() ?? "*/*")  // => "text/html; charset=utf-8"
```

## Adding `MimeType` as a Dependency

To use the `MimeType` library in a SwiftPM project, 
add it to the dependencies for your package:

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/nnabeyang/swift-mime-type", from: "0.0.0"),
    ],
    targets: [
        .executableTarget(name: "<executable-target-name>", dependencies: [
            // other dependencies
            .product(name: "MimeType", package: "swift-mime-type"),
        ]),
        // other targets
    ]
)
```

## License

swift-media-type is published under the MIT License, see LICENSE.

## Author
[Noriaki Watanabe@nnabeyang](https://twitter.com/nnabeyang)
