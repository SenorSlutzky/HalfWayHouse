import Foundation
import FirebaseDatabase
import FirebaseStorage

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Database.database().reference()
    private let storage = Storage.storage().reference()
    
    private init() {}
    
    // MARK: - Users
    
    func userExists(uid: String) async -> Bool {
        do {
            let snapshot = try await db.child("users/\(uid)").getData()
            return snapshot.exists()
        } catch {
            return false
        }
    }
    
    func createUser(_ user: HWHUser) async {
        let data: [String: Any] = [
            "displayName": user.displayName,
            "email": user.email,
            "handicap": user.handicap as Any,
            "homeCourse": user.homeCourse as Any,
            "avatarURL": user.avatarURL as Any,
            "friends": user.friends,
            "createdAt": user.createdAt.timeIntervalSince1970
        ]
        
        do {
            try await db.child("users/\(user.id)").setValue(data)
        } catch {
            print("Error creating user: \(error)")
        }
    }
    
    func getUser(uid: String) async -> HWHUser? {
        do {
            let snapshot = try await db.child("users/\(uid)").getData()
            guard let data = snapshot.value as? [String: Any] else { return nil }
            
            return HWHUser(
                id: uid,
                displayName: data["displayName"] as? String ?? "",
                email: data["email"] as? String ?? "",
                handicap: data["handicap"] as? Double,
                homeCourse: data["homeCourse"] as? String,
                avatarURL: data["avatarURL"] as? String,
                friends: data["friends"] as? [String] ?? [],
                createdAt: Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? 0)
            )
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
    func updateUser(_ user: HWHUser) async {
        let data: [String: Any] = [
            "displayName": user.displayName,
            "handicap": user.handicap as Any,
            "homeCourse": user.homeCourse as Any,
            "avatarURL": user.avatarURL as Any,
            "friends": user.friends
        ]
        
        do {
            try await db.child("users/\(user.id)").updateChildValues(data)
        } catch {
            print("Error updating user: \(error)")
        }
    }
    
    // MARK: - Friends
    
    func addFriend(userId: String, friendId: String) async {
        do {
            // Add bidirectional friendship
            let userFriends = db.child("users/\(userId)/friends")
            let friendFriends = db.child("users/\(friendId)/friends")
            
            var userList = (try await userFriends.getData()).value as? [String] ?? []
            var friendList = (try await friendFriends.getData()).value as? [String] ?? []
            
            if !userList.contains(friendId) { userList.append(friendId) }
            if !friendList.contains(userId) { friendList.append(userId) }
            
            try await userFriends.setValue(userList)
            try await friendFriends.setValue(friendList)
        } catch {
            print("Error adding friend: \(error)")
        }
    }
    
    func getFriends(userId: String) async -> [HWHUser] {
        guard let user = await getUser(uid: userId) else { return [] }
        var friends: [HWHUser] = []
        for friendId in user.friends {
            if let friend = await getUser(uid: friendId) {
                friends.append(friend)
            }
        }
        return friends
    }
    
    // MARK: - Rounds
    
    func createRound(_ round: Round) async throws {
        let data: [String: Any] = [
            "courseId": round.courseId,
            "courseName": round.courseName,
            "groupId": round.groupId as Any,
            "format": round.format.rawValue,
            "games": round.games.map { $0.rawValue },
            "status": round.status.rawValue,
            "players": round.players,
            "createdBy": round.createdBy,
            "createdAt": round.createdAt.timeIntervalSince1970
        ]
        
        try await db.child("rounds/\(round.id)").setValue(data)
        
        // Also add to each player's active rounds
        for playerId in round.players {
            try await db.child("users/\(playerId)/activeRounds/\(round.id)").setValue(true)
        }
    }
    
    func getRound(roundId: String) async throws -> Round? {
        let snapshot = try await db.child("rounds/\(roundId)").getData()
        guard let data = snapshot.value as? [String: Any] else { return nil }
        
        return Round(
            id: roundId,
            courseId: data["courseId"] as? String ?? "",
            courseName: data["courseName"] as? String ?? "",
            groupId: data["groupId"] as? String,
            format: ScoringFormat(rawValue: data["format"] as? String ?? "") ?? .strokePlay,
            games: (data["games"] as? [String] ?? []).compactMap { GameType(rawValue: $0) },
            status: RoundStatus(rawValue: data["status"] as? String ?? "") ?? .active,
            players: data["players"] as? [String] ?? [],
            createdBy: data["createdBy"] as? String ?? "",
            createdAt: Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? 0),
            completedAt: nil
        )
    }
    
    func getActiveRoundsForUser(userId: String) async -> [Round] {
        do {
            let snapshot = try await db.child("users/\(userId)/activeRounds").getData()
            guard let roundIds = snapshot.value as? [String: Any] else { return [] }
            
            var rounds: [Round] = []
            for roundId in roundIds.keys {
                if let round = try? await getRound(roundId: roundId),
                   round?.status == .active {
                    rounds.append(round!)
                }
            }
            return rounds
        } catch {
            return []
        }
    }
    
    func updateRoundStatus(roundId: String, status: RoundStatus) async throws {
        try await db.child("rounds/\(roundId)/status").setValue(status.rawValue)
        if status == .completed {
            try await db.child("rounds/\(roundId)/completedAt").setValue(Date().timeIntervalSince1970)
        }
    }
    
    // MARK: - Scores
    
    func submitHoleScore(roundId: String, userId: String, holeScore: HoleScore) async throws {
        let data: [String: Any] = [
            "strokes": holeScore.strokes,
            "putts": holeScore.putts as Any,
            "fairwayHit": holeScore.fairwayHit as Any,
            "gir": holeScore.greenInRegulation as Any,
            "timestamp": holeScore.timestamp.timeIntervalSince1970
        ]
        
        try await db.child("rounds/\(roundId)/scores/\(userId)/holes/hole\(holeScore.holeNumber)").setValue(data)
    }
    
    // MARK: - Courses
    
    func getCourse(courseId: String) async -> Course? {
        do {
            let snapshot = try await db.child("courses/\(courseId)").getData()
            guard let data = snapshot.value as? [String: Any] else { return nil }
            
            var holes: [HoleInfo] = []
            if let holesData = data["holes"] as? [[String: Any]] {
                for (index, holeData) in holesData.enumerated() {
                    holes.append(HoleInfo(
                        number: index + 1,
                        par: holeData["par"] as? Int ?? 4,
                        yardage: holeData["yardage"] as? Int ?? 0,
                        handicapIndex: holeData["handicapIndex"] as? Int ?? (index + 1)
                    ))
                }
            }
            
            return Course(
                id: courseId,
                name: data["name"] as? String ?? "",
                city: data["city"] as? String ?? "",
                state: data["state"] as? String ?? "",
                slopeRating: data["slopeRating"] as? Int ?? 113,
                courseRating: data["courseRating"] as? Double ?? 72.0,
                holes: holes
            )
        } catch {
            return nil
        }
    }
    
    func searchCourses(query: String) async -> [Course] {
        // For MVP: search by name prefix
        do {
            let snapshot = try await db.child("courses")
                .queryOrdered(byChild: "name")
                .queryStarting(atValue: query)
                .queryEnding(atValue: query + "\u{f8ff}")
                .queryLimited(toFirst: 20)
                .getData()
            
            var courses: [Course] = []
            for child in snapshot.children {
                guard let snap = child as? DataSnapshot,
                      let data = snap.value as? [String: Any] else { continue }
                
                let course = Course(
                    id: snap.key,
                    name: data["name"] as? String ?? "",
                    city: data["city"] as? String ?? "",
                    state: data["state"] as? String ?? "",
                    slopeRating: data["slopeRating"] as? Int ?? 113,
                    courseRating: data["courseRating"] as? Double ?? 72.0,
                    holes: [] // Light version for search results
                )
                courses.append(course)
            }
            return courses
        } catch {
            return []
        }
    }
    
    // MARK: - Chat
    
    func sendChatMessage(_ message: ChatMessage) async {
        let data: [String: Any] = [
            "userId": message.userId,
            "userName": message.userName,
            "type": message.type.rawValue,
            "text": message.text as Any,
            "imageURL": message.imageURL as Any,
            "holeNumber": message.holeNumber as Any,
            "timestamp": message.timestamp.timeIntervalSince1970
        ]
        
        do {
            try await db.child("rounds/\(message.roundId)/chat/\(message.id)").setValue(data)
        } catch {
            print("Error sending message: \(error)")
        }
    }
    
    // MARK: - Image Upload
    
    func uploadImage(imageData: Data, path: String) async -> String? {
        let ref = storage.child(path)
        
        do {
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            print("Error uploading image: \(error)")
            return nil
        }
    }
    
    // MARK: - Invite Codes
    
    func generateInviteCode(userId: String) async -> String {
        let code = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        
        do {
            try await db.child("inviteCodes/\(code)").setValue([
                "userId": userId,
                "createdAt": Date().timeIntervalSince1970,
                "expiresAt": Date().addingTimeInterval(7 * 24 * 3600).timeIntervalSince1970
            ])
        } catch {
            print("Error generating invite code: \(error)")
        }
        
        return code
    }
    
    func redeemInviteCode(code: String, userId: String) async -> Bool {
        do {
            let snapshot = try await db.child("inviteCodes/\(code)").getData()
            guard let data = snapshot.value as? [String: Any],
                  let inviterUserId = data["userId"] as? String,
                  let expiresAt = data["expiresAt"] as? TimeInterval else { return false }
            
            // Check expiration
            guard Date().timeIntervalSince1970 < expiresAt else { return false }
            
            // Add friendship
            await addFriend(userId: userId, friendId: inviterUserId)
            
            // Delete used code
            try await db.child("inviteCodes/\(code)").removeValue()
            
            return true
        } catch {
            return false
        }
    }
}
