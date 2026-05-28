const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.database();

/**
 * When a player submits a score, recalculate the leaderboard
 * and send push notifications to other players.
 */
exports.onScoreUpdate = functions.database
  .ref("/rounds/{roundId}/scores/{userId}/holes/{holeId}")
  .onWrite(async (change, context) => {
    const { roundId, userId, holeId } = context.params;

    // Get round metadata
    const roundSnap = await db.ref(`/rounds/${roundId}`).once("value");
    const round = roundSnap.val();
    if (!round || round.status !== "active") return;

    // Get all scores for this round
    const scoresSnap = await db
      .ref(`/rounds/${roundId}/scores`)
      .once("value");
    const scores = scoresSnap.val() || {};

    // Get course data for par info
    const courseSnap = await db
      .ref(`/courses/${round.courseId}`)
      .once("value");
    const course = courseSnap.val();

    // Calculate leaderboard
    const leaderboard = [];
    for (const [playerId, playerData] of Object.entries(scores)) {
      const holes = playerData.holes || {};
      let grossTotal = 0;
      let holesCompleted = 0;
      let relativeToPar = 0;

      for (const [holeKey, holeData] of Object.entries(holes)) {
        const holeNum = parseInt(holeKey.replace("hole", ""));
        if (holeData.strokes) {
          grossTotal += holeData.strokes;
          holesCompleted++;
          if (course && course.holes && course.holes[holeNum - 1]) {
            relativeToPar += holeData.strokes - course.holes[holeNum - 1].par;
          }
        }
      }

      const courseHandicap = playerData.courseHandicap || 0;
      const netTotal = grossTotal - courseHandicap;

      leaderboard.push({
        playerId,
        playerName: playerData.playerName || "Unknown",
        grossTotal,
        netTotal,
        relativeToPar,
        holesCompleted,
        lastUpdated: Date.now(),
      });
    }

    // Sort by net total
    leaderboard.sort((a, b) => {
      if (a.holesCompleted === 0 && b.holesCompleted > 0) return 1;
      if (b.holesCompleted === 0 && a.holesCompleted > 0) return -1;
      return a.netTotal - b.netTotal;
    });

    // Assign positions
    leaderboard.forEach((entry, index) => {
      entry.position = index + 1;
    });

    // Save leaderboard
    await db.ref(`/rounds/${roundId}/leaderboard`).set(leaderboard);

    // Send push notifications to other players
    const holeNum = parseInt(holeId.replace("hole", ""));
    const scorerName = scores[userId]?.playerName || "Someone";
    const strokes = change.after.val()?.strokes;

    if (strokes && course && course.holes) {
      const par = course.holes[holeNum - 1]?.par || 4;
      const diff = strokes - par;

      let notificationBody = "";
      if (diff <= -2) notificationBody = `🦅 ${scorerName} just EAGLED Hole ${holeNum}!`;
      else if (diff === -1) notificationBody = `🐦 ${scorerName} birdied Hole ${holeNum}!`;
      else if (diff === 2) notificationBody = `😬 ${scorerName} doubled Hole ${holeNum}`;
      else if (diff >= 3)
        notificationBody = `💀 ${scorerName} made ${strokes} on the par ${par}...`;

      if (notificationBody) {
        // Get FCM tokens for other players
        const players = round.players || [];
        const otherPlayers = players.filter((p) => p !== userId);

        for (const playerId of otherPlayers) {
          const tokenSnap = await db
            .ref(`/users/${playerId}/fcmToken`)
            .once("value");
          const token = tokenSnap.val();

          if (token) {
            try {
              await admin.messaging().send({
                token,
                notification: {
                  title: "Half Way House",
                  body: notificationBody,
                },
                data: {
                  roundId,
                  type: "score_update",
                },
              });
            } catch (err) {
              console.log(`Failed to send notification to ${playerId}:`, err.message);
            }
          }
        }
      }
    }
  });

/**
 * Calculate Skins results when scores are updated.
 */
exports.calculateSkins = functions.database
  .ref("/rounds/{roundId}/scores/{userId}/holes/{holeId}")
  .onWrite(async (change, context) => {
    const { roundId } = context.params;

    const roundSnap = await db.ref(`/rounds/${roundId}`).once("value");
    const round = roundSnap.val();
    if (!round || !round.games || !round.games.includes("Skins")) return;

    const scoresSnap = await db
      .ref(`/rounds/${roundId}/scores`)
      .once("value");
    const scores = scoresSnap.val() || {};

    // Find the max hole all players have completed
    let maxCommonHole = 18;
    for (const playerData of Object.values(scores)) {
      const holes = playerData.holes || {};
      const completedHoles = Object.keys(holes)
        .map((k) => parseInt(k.replace("hole", "")))
        .filter((n) => !isNaN(n));
      if (completedHoles.length > 0) {
        maxCommonHole = Math.min(maxCommonHole, Math.max(...completedHoles));
      } else {
        maxCommonHole = 0;
      }
    }

    if (maxCommonHole === 0) return;

    // Calculate skins
    const skinResults = [];
    let carryOvers = 0;

    for (let hole = 1; hole <= maxCommonHole; hole++) {
      const holeScores = [];
      for (const [playerId, playerData] of Object.entries(scores)) {
        const holeData = playerData.holes?.[`hole${hole}`];
        if (holeData?.strokes) {
          holeScores.push({
            playerId,
            playerName: playerData.playerName || "Unknown",
            strokes: holeData.strokes,
          });
        }
      }

      if (holeScores.length < 2) {
        skinResults.push({ hole, winner: null, pushed: true });
        carryOvers++;
        continue;
      }

      const minScore = Math.min(...holeScores.map((s) => s.strokes));
      const winners = holeScores.filter((s) => s.strokes === minScore);

      if (winners.length === 1) {
        skinResults.push({
          hole,
          winner: winners[0].playerId,
          winnerName: winners[0].playerName,
          skinsWon: 1 + carryOvers,
          pushed: false,
        });
        carryOvers = 0;
      } else {
        skinResults.push({ hole, winner: null, pushed: true });
        carryOvers++;
      }
    }

    await db.ref(`/rounds/${roundId}/games/skins`).set({
      results: skinResults,
      carryOvers,
      lastUpdated: Date.now(),
    });
  });
