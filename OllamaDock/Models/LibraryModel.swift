import Foundation

struct LibraryModel: Equatable, Identifiable, Decodable {
    let name: String
    let sizeOnDisk: UInt64

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name
        case sizeOnDisk = "size"
    }
}

struct TagsResponse: Decodable {
    let models: [LibraryModel]
}
