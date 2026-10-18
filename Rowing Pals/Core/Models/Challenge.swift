//
//  Challenge.swift
//  Rowing Pals
//

import Foundation

/// A club challenge (decision 91; mirrors `challenges`): its kind, name, the metres to aim for (a
/// personal target or a club total) or the squads racing, and its first and last days.
nonisolated struct Challenge: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let clubId: UUID
    let kind: ChallengeKind
    let title: String
    let targetM: Int?
    let squadIds: [UUID]
    /// "yyyy-MM-dd", the club's own calendar days, both counted.
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case id, kind, title
        case clubId = "club_id"
        case targetM = "target_m"
        case squadIds = "squad_ids"
        case startsOn = "starts_on"
        case endsOn = "ends_on"
    }

    init(id: UUID, clubId: UUID, kind: ChallengeKind, title: String, targetM: Int?, squadIds: [UUID] = [],
         startsOn: String, endsOn: String) {
        self.id = id
        self.clubId = clubId
        self.kind = kind
        self.title = title
        self.targetM = targetM
        self.squadIds = squadIds
        self.startsOn = startsOn
        self.endsOn = endsOn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        clubId = try c.decode(UUID.self, forKey: .clubId)
        kind = try c.decode(ChallengeKind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        targetM = try c.decodeIfPresent(Int.self, forKey: .targetM)
        squadIds = try c.decodeIfPresent([UUID].self, forKey: .squadIds) ?? []
        startsOn = try c.decode(String.self, forKey: .startsOn)
        endsOn = try c.decode(String.self, forKey: .endsOn)
    }
}
