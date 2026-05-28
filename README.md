# 🏌️ Half Way House

**The turn just got interesting.**

Live golf scoring app for competing with friends across different courses. Real-time leaderboards, trash talk, and automatic side game tracking — no matter where your crew is playing.

---

## What Is This?

Half Way House is like the snack shack at the turn: where you stop, check scores, talk shit, and size up the competition. Except now it lives in your pocket and works whether your buddy is at the same course or three states away.

## Core Features

- **Live Scoring** — Hole-by-hole score entry with real-time sync
- **Cross-Course Leaderboard** — Compete with friends playing different courses simultaneously
- **Auto Game Tracking** — Skins, Nassau, Match Play calculated automatically
- **Trash Talk Feed** — Real-time chat, photo sharing, and reactions during rounds
- **Push Notifications** — "Mike just triple-bogeyed Hole 7 💀"
- **Handicap-Adjusted** — Net scoring so all skill levels compete fairly
- **Game History** — Past rounds, stats, and season standings

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | SwiftUI (iOS 17+) |
| Backend | Firebase Realtime Database |
| Auth | Firebase Auth (Apple Sign-In) |
| Push | Firebase Cloud Messaging |
| Photos | Firebase Storage |
| Logic | Firebase Cloud Functions |

## Scoring Formats

### MVP
- Stroke Play (Gross & Net)
- Skins
- Match Play

### Phase 2
- Nassau (Front/Back/Total)
- Stableford
- Wolf

### Phase 3
- Sixes, Vegas, Dots, Rolling Stroke, Targets

## Architecture

```
/users/{userId}/
  ├── profile (name, handicap, avatar, home course)
  ├── stats (rounds played, avg score, best round)
  └── friends: [userId1, userId2...]

/groups/{groupId}/
  ├── metadata (name, members, created)
  ├── season/ (ongoing league standings)
  └── settings (scoring format defaults)

/rounds/{roundId}/
  ├── metadata (courseId, date, format, status, players)
  ├── scores/{userId}/hole{N}: { strokes, putts }
  ├── leaderboard: [{userId, gross, net, position, thru}]
  ├── games/{gameType}: { results }
  └── chat/{messageId}: { userId, text, timestamp, type }

/courses/{courseId}/
  ├── name, city, state, slope, rating
  └── holes: [{par, yardage, handicapIndex}...]
```

## Project Structure

```
HalfWayHouse/
├── HalfWayHouse.xcodeproj
├── HalfWayHouse/
│   ├── App/
│   │   ├── HalfWayHouseApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Round.swift
│   │   ├── Course.swift
│   │   ├── Score.swift
│   │   └── ChatMessage.swift
│   ├── Views/
│   │   ├── Home/
│   │   ├── Scorecard/
│   │   ├── Leaderboard/
│   │   ├── Chat/
│   │   ├── Profile/
│   │   └── Friends/
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── RoundViewModel.swift
│   │   ├── LeaderboardViewModel.swift
│   │   └── ChatViewModel.swift
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── AuthService.swift
│   │   ├── ScoringEngine.swift
│   │   ├── NotificationService.swift
│   │   └── CourseDatabase.swift
│   ├── Utilities/
│   │   ├── Extensions.swift
│   │   └── Constants.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── GoogleService-Info.plist
├── Firebase/
│   ├── firestore.rules
│   ├── database.rules.json
│   └── functions/
│       ├── index.js
│       └── package.json
└── Tests/
```

## Development Phases

### Phase 1: Foundation (Weeks 1-2)
- [x] Create repo
- [ ] Xcode project setup
- [ ] Firebase project config
- [ ] Apple Sign-In auth flow
- [ ] User profile creation
- [ ] Friend system (invite via code)
- [ ] Course data model + seed data

### Phase 2: Core Scoring (Weeks 3-4)
- [ ] Scorecard entry UI (swipeable holes)
- [ ] Stroke play scoring engine
- [ ] Real-time Firebase writes
- [ ] Live leaderboard view
- [ ] Skins auto-calculation
- [ ] Offline score entry + sync

### Phase 3: Social & Notifications (Weeks 5-6)
- [ ] Per-round chat (text + photos)
- [ ] Push notifications on score entry
- [ ] Photo capture per hole
- [ ] Emoji reactions
- [ ] Match play format

### Phase 4: Polish & Ship (Weeks 7-8)
- [ ] Game history browser
- [ ] Player stats dashboard
- [ ] UI polish + animations
- [ ] TestFlight beta
- [ ] App Store submission

## Inspired By

- **Golf Genius** — Live leaderboards, tournament formats, league play
- **18 Birdies** — Virtual tournaments, 10 game formats, group scorecards, social feed, 46K course database

## What Makes Half Way House Different

| Feature | Golf Genius | 18 Birdies | Half Way House |
|---------|------------|------------|----------------|
| Target user | Facilities/clubs | Individual golfers | Private friend groups |
| Setup | Club admin required | Account + premium | Invite link, done |
| Trash talk | ❌ | Basic feed | Core feature, push alerts |
| Cross-course play | Via tournaments | Virtual tournaments | Default mode |
| Side games auto-calc | ❌ | ✅ 10 formats | ✅ Starting with 3 |
| Cost | $$$$ (club pays) | Free + $9.99/mo premium | Free |
| Focus | Operations | Individual improvement | Competition & banter |

## License

Private project. All rights reserved.

---

*Built with SwiftUI + Firebase. Designed for the crew.*
