//
//  Confidence.swift
//  PaceEngine
//
//  Port of `_score_confidence`. The clamp cap is applied by the predictor, after this, as in
//  the Python.
//

import Foundation

/// Base score by anchor tier and recency, less penalties, clamped to 5–95, then banded.
func scoreConfidence(
    anchor: Anchor,
    sessions: [Session],
    targetDistance: Double,
    spreadS: Double,
    asOfDay: Int,
    config: EngineConfig,
    fatigueExcess: Double?
) -> (score: Int, band: Prediction.ConfidenceBand, factors: [Prediction.ConfidenceFactor], recommendations: [String]) {
    var factors: [Prediction.ConfidenceFactor] = []
    var recommendations: [String] = []
    let daysAgo = asOfDay - anchor.day

    var score: Int
    let label: String
    if anchor.tag == .an && daysAgo <= config.recentAnchorDays {
        (score, label) = (90, "Recent all-out test piece")
    } else if anchor.tag == .tr && daysAgo <= config.recentAnchorDays {
        (score, label) = (80, "Recent race-pace work")
    } else if anchor.tier.isMaximal {
        (score, label) = (65, "\(anchor.tag.rawValue) anchor, \(daysAgo) days old")
    } else if anchor.tag == .at {
        (score, label) = (60, "Threshold work only")
    } else if anchor.tag == .ut1 {
        (score, label) = (42, "Low-intensity anchor only")
    } else {
        (score, label) = (35, "Steady-state volume only")
    }
    factors.append(.init(label: label, delta: score))

    if !anchor.tier.isMaximal || daysAgo > config.recentAnchorDays {
        recommendations.append(
            "Log an all-out test piece (AN) or a hard race-pace effort (TR) in the next "
                + "two weeks to raise confidence."
        )
    }

    let target = Int(targetDistance)
    let ratioLog2 = abs(log2(targetDistance / Py.max(anchor.effectiveDistanceM, 1e-9)))
    if ratioLog2 > config.ratioSevereLog2 {
        factors.append(.init(
            label: "Anchor distance is far from \(target)m "
                + "(\(String(format: "%.1f", ratioLog2)) doublings apart)",
            delta: -25
        ))
        score -= 25
        recommendations.append(
            "Paul's Law is unreliable across this distance gap. A piece nearer "
                + "\(target)m would sharply improve this prediction."
        )
    } else if ratioLog2 > config.ratioWarnLog2 {
        factors.append(.init(
            label: "Anchor distance differs from target by \(String(format: "%.1f", ratioLog2)) doublings",
            delta: -15
        ))
        score -= 15
    }

    let count = sessions.count
    if count < config.minSessionsMinimum {
        factors.append(.init(label: "Only \(count) session(s) in the window", delta: -20))
        score -= 20
    } else if count < config.minSessionsComfortable {
        factors.append(.init(label: "Only \(count) sessions in the window", delta: -12))
        score -= 12
    }

    if let lastSessionDays = sessions.map({ asOfDay - $0.day }).min(),
       lastSessionDays > config.staleHistoryDays {
        factors.append(.init(label: "No sessions logged in \(lastSessionDays) days", delta: -10))
        score -= 10
        recommendations.append("Log recent sessions — this history has gone stale.")
    }

    if anchor.rateMismatch {
        let tier = anchor.tier
        factors.append(.init(
            label: "Anchor stroke rate is outside the usual \(anchor.tag.rawValue) range "
                + "(\(String(format: "%.0f", tier.rateLo))-\(String(format: "%.0f", tier.rateHi)) spm)",
            delta: -10
        ))
        score -= 10
        recommendations.append(
            "Check the intensity tag on the anchor session — the stroke rate does not "
                + "look like \(anchor.tag.rawValue)."
        )
    }

    if spreadS > config.tierSpreadToleranceS {
        factors.append(.init(
            label: "Intensity zones disagree by \(String(format: "%.1f", spreadS))s per 500m",
            delta: -10
        ))
        score -= 10
        recommendations.append(
            "Your zones imply different fitness levels. Reviewing how sessions are tagged "
                + "would tighten every prediction."
        )
    }

    if anchor.intervalAmbiguous {
        factors.append(.init(
            label: "Anchor may be an interval session with no rep distance recorded",
            delta: -15
        ))
        score -= 15
        recommendations.append(
            "Record the rep distance on interval sessions — it is the single biggest "
                + "accuracy win available."
        )
    }

    if anchor.rpeMismatch {
        let tier = anchor.tier
        let reported = anchor.rpe.map { " (RPE \(String(format: "%.1f", $0)))" } ?? ""
        factors.append(.init(
            label: "Anchor effort\(reported) doesn't match a typical "
                + "\(anchor.tag.rawValue) session (RPE \(Py.g(tier.rpeLo))-\(Py.g(tier.rpeHi)))",
            delta: -10
        ))
        score -= 10
        recommendations.append(
            "The effort you reported doesn't look like \(anchor.tag.rawValue). Check the zone tag "
                + "on that session."
        )
    }

    if let fatigueExcess, fatigueExcess > config.fatigueRpeExcess {
        factors.append(.init(
            label: "Recent sessions have felt harder than usual "
                + "(+\(String(format: "%.1f", fatigueExcess)) RPE)",
            delta: -8
        ))
        score -= 8
        recommendations.append(
            "Your recent sessions are feeling harder than their zones normally do. If "
                + "you're carrying fatigue, a test now would likely come in slower than this "
                + "prediction — a few easier days first would give a truer result."
        )
    }

    score = max(5, min(95, score))
    let band: Prediction.ConfidenceBand
    if score >= config.highThreshold {
        band = .high
    } else if score >= config.mediumThreshold {
        band = .medium
    } else {
        band = .low
    }
    return (score, band, factors, recommendations)
}
