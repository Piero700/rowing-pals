//
//  PacePredictor.swift
//  PaceEngine
//
//  Port of `predict_test_piece`, `_population_estimate_result` and `_empty_result`.
//

import Foundation

public enum PacePredictor {
    public static let schemaVersion = "anchor-impulse/1.3.1"

    /// Predicts a test-piece split and total time from session-summary history.
    ///
    /// - Parameters:
    ///   - history: logged sessions, in any order. Repeated ids keep the last copy.
    ///   - targetDistance: metres, positive.
    ///   - asOf: the evaluation day. Always passed in; the engine never reads the clock.
    ///   - calendar: whose calendar days `asOf` and every session date are read in.
    ///   - config: tunables; `.default` is the reference calibration.
    ///   - athlete: optional profile. Drives interpretation and the cold-start prior only.
    /// - Returns: never fails on bad input — every failure is a null prediction (or a
    ///   labelled population estimate) plus warnings and flags.
    public static func predict(
        history: [SessionInput],
        targetDistance: Double,
        asOf: Date,
        calendar: Calendar = .current,
        config: EngineConfig = .default,
        athlete: AthleteProfile? = nil
    ) -> Prediction {
        var warnings: [String] = []
        var flags: [String] = []
        let profile = normaliseAthlete(athlete, warnings: &warnings)

        let days = CalendarDays(calendar: calendar)
        let asOfDay = days.number(asOf)
        let asOfISO = days.iso(asOf)

        guard let target = toFloat(targetDistance), target > 0 else {
            return emptyResult(
                targetDistance: targetDistance, config: config,
                warnings: warnings + ["Target distance must be a positive number, got \(Py.repr(targetDistance))"],
                flags: ["invalid_target_distance"]
            )
        }
        if target < 100 {
            warnings.append(
                "Target of \(String(format: "%.0f", target))m is below the range Paul's Law was "
                    + "derived over; treat the result as indicative only"
            )
            flags.append("target_below_supported_range")
        }

        let rawSessions = dedupe(history, warnings: &warnings, flags: &flags)
        let rawDays = rawSessions.map { days.number($0.date) }

        var parsed = rawSessions.enumerated().compactMap { index, raw in
            normaliseSession(raw, index: index, day: rawDays[index], config: config, warnings: &warnings)
        }

        let future = parsed.filter { $0.day > asOfDay }
        if !future.isEmpty {
            warnings.append("\(future.count) session(s) dated after \(asOfISO) were ignored")
            flags.append("future_dated_session")
            parsed = parsed.filter { $0.day <= asOfDay }
        }

        let cutoff = asOfDay - config.windowDays
        let window = parsed.filter { $0.day >= cutoff }

        // --- Cold start and near-cold start ---------------------------------------------
        if window.isEmpty {
            if let newest = parsed.map(\.day).max() {
                let staleDays = asOfDay - newest
                warnings.append(
                    "No sessions inside the \(config.windowDays)-day window; the most recent "
                        + "is \(staleDays) days old"
                )
                flags.append("history_outside_window")
            } else {
                warnings.append("No usable sessions found")
                flags.append("cold_start")
            }
            // A population estimate only with NO rowing history at all: a stale real result
            // is better evidence than a seed number.
            if !profile.isEmpty && parsed.isEmpty {
                return populationEstimateResult(target: target, profile: profile, config: config,
                                                warnings: warnings, flags: flags, asOfISO: asOfISO)
            }
            return emptyResult(targetDistance: target, config: config, warnings: warnings, flags: flags)
        }

        guard let anchor = selectAnchor(window, targetDistance: target, config: config) else {
            warnings.append("No session in the window qualified as an anchor")
            flags.append("no_anchor")
            return emptyResult(targetDistance: target, config: config, warnings: warnings, flags: flags)
        }

        let diagnostics = diagnoseHistory(rawSessions, days: rawDays, asOfDay: asOfDay, config: config)
        let spread = diagnostics.spreadSeconds

        // --- Step 3: recover S2k from the anchor, then project to the target ------------
        let tier = anchor.tier
        var referenceSplit: Double
        let paulAdjustment: Double
        let intensityOffset: Double
        var baseSplit: Double
        let projection: Double
        let rpeCorrection: Double
        if config.legacyV1Formula {
            // The original v1.0 single-step formula, kept only so its divergence is measurable.
            referenceSplit = .nan
            paulAdjustment = config.paulConstant * log2(target / Py.max(anchor.effectiveDistanceM, 1e-9))
            intensityOffset = -tier.offset
            baseSplit = anchor.splitS + paulAdjustment + intensityOffset
            projection = 0.0
            flags.append("legacy_v1_formula_enabled")
            rpeCorrection = 0.0
        } else {
            let recovered = normaliseToReference(split: anchor.splitS,
                                                 effectiveDistanceM: anchor.effectiveDistanceM,
                                                 tier: tier, config: config)
            referenceSplit = recovered.s2k
            paulAdjustment = recovered.paulAdjustment
            intensityOffset = recovered.intensityOffset
            // Perceived effort refines where in its tier the anchor actually sat.
            rpeCorrection = rpeOffsetCorrection(rpe: anchor.rpe, tier: tier,
                                                rpeMismatch: anchor.rpeMismatch, config: config)
                * anchor.rpeCoverage
            referenceSplit += rpeCorrection
            // A test piece is maximal by definition: project at full Paul weight.
            projection = config.paulConstant * log2(target / config.referenceDistanceM)
            baseSplit = referenceSplit + projection
        }

        // --- Bodyweight trend (off by default) ------------------------------------------
        let trend = weightTrendCorrection(window: window, anchor: anchor, baseSplit: baseSplit, config: config)
        if let anchorWeight = trend.anchorWeight, let currentWeight = trend.currentWeight,
           abs(currentWeight - anchorWeight) >= config.weightTrendMinKg {
            flags.append(trend.correction == 0.0 ? "weight_change_not_applied" : "weight_trend_applied")
        }
        baseSplit += trend.correction

        // --- Fatigue read from RPE (confidence and advice only, never pace) -------------
        let fatigueCutoff = asOfDay - config.fatigueWindowDays
        let recentRated = window.filter { $0.day >= fatigueCutoff && $0.rpe != nil && !$0.rpeMismatch }
        let fatigueExcess: Double? = recentRated.count >= 2
            ? Py.sum(recentRated.map(\.rpeDeviation)) / Double(recentRated.count)
            : nil
        if let fatigueExcess, fatigueExcess > config.fatigueRpeExcess {
            flags.append("elevated_recent_effort")
        }
        if anchor.rpeMismatch {
            flags.append("anchor_tag_rpe_mismatch")
        }

        // --- Step 4: volume modifier, damped by how much history it rests on ------------
        let load = rollingLoad(window)
        let rawModifier = interpolate(config.loadKnots, load)
        let loadConfidence = Py.min(1.0, Double(window.count) / Double(config.minSessionsComfortable))
        let volumeModifier = rawModifier * loadConfidence
        if loadConfidence < 1.0 {
            flags.append("load_estimate_damped")
        }
        let modelledSplit = baseSplit + volumeModifier

        // --- Clamps ----------------------------------------------------------------------
        let floor = config.floorSplitAtReference
            + config.paulConstant * log2(target / config.referenceDistanceM)
        var finalSplit = modelledSplit
        if modelledSplit < floor {
            finalSplit = floor
            flags.append("clamped_to_physiological_floor")
            warnings.append(
                "The model produced a split faster than world-record pace and has been clamped. "
                    + "This usually means a mis-tagged session or a mis-entered distance."
            )
        } else if modelledSplit > config.ceilingSplit {
            finalSplit = config.ceilingSplit
            flags.append("clamped_to_ceiling")
            warnings.append("The model produced an implausibly slow split and has been clamped.")
        }

        if anchor.intervalAmbiguous {
            flags.append("interval_structure_ambiguous")
        }
        if anchor.rateMismatch {
            flags.append("anchor_tag_rate_mismatch")
        }
        if spread > config.tierSpreadToleranceS {
            flags.append("tier_disagreement")
        }

        var confidence = scoreConfidence(anchor: anchor, sessions: window, targetDistance: target,
                                         spreadS: spread, asOfDay: asOfDay, config: config,
                                         fatigueExcess: fatigueExcess)

        // A clamped result is physiologically impossible input: cap it at Low and say why.
        if finalSplit != modelledSplit {
            let capped = min(confidence.score, config.mediumThreshold - 1)
            if capped < confidence.score {
                confidence.factors.append(.init(
                    label: "Prediction hit a physiological limit — check the anchor session for "
                        + "a typo or wrong zone",
                    delta: capped - confidence.score
                ))
                confidence.score = capped
            }
            confidence.band = .low
            confidence.recommendations.append(
                "One of your sessions produced an impossible result. Check the distance, time "
                    + "and zone on your most recent hard session."
            )
        }

        let totalTime = finalSplit * target / 500.0
        let ratedCount = window.filter { $0.rpe != nil }.count

        return Prediction(
            schemaVersion: schemaVersion,
            generatedForDate: asOfISO,
            targetDistanceM: Py.round(target, 1),
            predictedSplitSeconds: Py.round(finalSplit, 2),
            predictedSplitFormatted: formatSeconds(finalSplit),
            predictedTotalTimeSeconds: Py.round(totalTime, 2),
            predictedTotalTimeFormatted: formatSeconds(totalTime),
            confidenceScore: confidence.band,
            confidenceNumeric: confidence.score,
            confidenceFactors: confidence.factors,
            anchor: .init(
                tier: anchor.tag,
                sessionIds: anchor.sessionIds,
                date: days.iso(anchor.date),
                daysAgo: asOfDay - anchor.day,
                splitSeconds: Py.round(anchor.splitS, 2),
                splitFormatted: formatSeconds(anchor.splitS),
                effectiveDistanceM: Py.round(anchor.effectiveDistanceM, 1),
                method: anchor.method,
                rpe: anchor.rpe.map { Py.round($0, 1) }
            ),
            load: .init(
                trimpLite: Py.round(load, 1),
                sessionCount: window.count,
                windowDays: config.windowDays,
                rawModifierSeconds: Py.round(rawModifier, 2),
                loadConfidence: Py.round(loadConfidence, 2),
                modifierSeconds: Py.round(volumeModifier, 2)
            ),
            components: .init(
                anchorSplit: Py.round(anchor.splitS, 2),
                paulAdjustment: Py.round(paulAdjustment, 2),
                intensityOffset: Py.round(intensityOffset, 2),
                rpeCorrection: Py.round(rpeCorrection, 2),
                twoKEquivalent: referenceSplit.isNaN ? nil : Py.round(referenceSplit, 2),
                projectionToTarget: Py.round(projection, 2),
                weightTrendCorrection: Py.round(trend.correction, 2),
                volumeModifier: Py.round(volumeModifier, 2),
                clampAdjustment: Py.round(finalSplit - modelledSplit, 2)
            ),
            estimateBasis: nil,
            effort: .init(
                sessionsWithRpe: ratedCount,
                anchorRpe: anchor.rpe.map { Py.round($0, 1) },
                recentRpeExcess: fatigueExcess.map { Py.round($0, 2) }
            ),
            athlete: .init(
                age: profile.age,
                sex: profile.sex,
                weightKg: profile.weightKg,
                bodyweightAtAnchorKg: trend.anchorWeight,
                usedInPrediction: trend.correction != 0.0
            ),
            interpretation: interpretation(split: finalSplit, targetDistance: target,
                                           athlete: profile, config: config),
            diagnostics: diagnostics,
            flags: flags,
            warnings: warnings,
            recommendations: confidence.recommendations
        )
    }

    /// `_population_estimate_result`: a demographic estimate for a user with no history at
    /// all, shaped so a UI cannot mistake it for a prediction.
    static func populationEstimateResult(
        target: Double,
        profile: Athlete,
        config: EngineConfig,
        warnings: [String],
        flags: [String],
        asOfISO: String
    ) -> Prediction {
        let prior = populationPrior2k(profile, config: config)
        let s2k = prior.seconds / 4.0
        let projection = config.paulConstant * log2(target / config.referenceDistanceM)
        let split = Py.min(Py.max(s2k + projection, config.floorSplitAtReference + projection),
                           config.ceilingSplit)
        let total = split * target / 500.0
        var flags = flags + ["population_estimate", "prior_is_seed_data"]
        if profile.sex == nil {
            flags.append("sex_neutral_prior")
        }

        return Prediction(
            schemaVersion: schemaVersion,
            generatedForDate: asOfISO,
            targetDistanceM: Py.round(target, 1),
            predictedSplitSeconds: Py.round(split, 2),
            predictedSplitFormatted: formatSeconds(split),
            predictedTotalTimeSeconds: Py.round(total, 2),
            predictedTotalTimeFormatted: formatSeconds(total),
            confidenceScore: .populationEstimate,
            confidenceNumeric: config.priorConfidenceNumeric,
            confidenceFactors: [.init(
                label: "No training data — estimate is based on people like you, not on you",
                delta: config.priorConfidenceNumeric
            )],
            anchor: nil,
            load: .empty(windowDays: config.windowDays),
            components: .init(
                twoKEquivalent: Py.round(s2k, 2),
                projectionToTarget: Py.round(projection, 2),
                population2kSeconds: Py.round(prior.seconds, 2)
            ),
            estimateBasis: prior.notes,
            effort: .init(sessionsWithRpe: 0, anchorRpe: nil, recentRpeExcess: nil),
            athlete: .init(age: profile.age, sex: profile.sex, weightKg: profile.weightKg,
                           bodyweightAtAnchorKg: nil, usedInPrediction: true),
            interpretation: interpretation(split: split, targetDistance: target, athlete: profile,
                                           config: config),
            diagnostics: .empty,
            flags: flags,
            warnings: warnings,
            recommendations: [
                "This is a starting estimate from population data. Log a few sessions — "
                    + "ideally one hard effort — and it will be replaced by a prediction built "
                    + "from your own rowing."
            ]
        )
    }

    /// `_empty_result`: the honest no-prediction response. Never a guessed number.
    static func emptyResult(
        targetDistance: Double,
        config: EngineConfig,
        warnings: [String],
        flags: [String]
    ) -> Prediction {
        let target = toFloat(targetDistance)
        return Prediction(
            schemaVersion: schemaVersion,
            generatedForDate: nil,
            targetDistanceM: target.flatMap { $0 > 0 ? Py.round($0, 1) : nil },
            predictedSplitSeconds: nil,
            predictedSplitFormatted: nil,
            predictedTotalTimeSeconds: nil,
            predictedTotalTimeFormatted: nil,
            confidenceScore: .insufficientData,
            confidenceNumeric: 0,
            confidenceFactors: [],
            anchor: nil,
            load: .empty(windowDays: config.windowDays),
            components: .init(),
            estimateBasis: nil,
            effort: .init(sessionsWithRpe: 0, anchorRpe: nil, recentRpeExcess: nil),
            athlete: nil,
            interpretation: nil,
            diagnostics: .empty,
            flags: flags,
            warnings: warnings,
            recommendations: ["Log a few sessions — ideally including one hard effort — to unlock predictions."]
        )
    }
}
