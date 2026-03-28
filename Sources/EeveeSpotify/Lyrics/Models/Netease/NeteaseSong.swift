import Foundation

struct NeteaseSong: Decodable {
    let id: Int
    let name: String
    let artists: [NeteaseArtist]
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artists = "ar"
    }
}


struct NeteaseArtist: Decodable {
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case name = "name"
    }
}
