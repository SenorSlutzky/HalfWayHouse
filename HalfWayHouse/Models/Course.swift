import Foundation

struct Course: Codable, Identifiable {
    var id: String
    var name: String
    var city: String
    var state: String
    var slopeRating: Int
    var courseRating: Double
    var holes: [HoleInfo]
    var totalPar: Int {
        holes.reduce(0) { $0 + $1.par }
    }
}

struct HoleInfo: Codable, Identifiable {
    var id: Int { number }
    var number: Int
    var par: Int
    var yardage: Int
    var handicapIndex: Int // 1-18, used for stroke allocation
}
