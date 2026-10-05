//
//  Inputs.swift
//  PaceEngine
//
//  Typed equivalents of the Python session and athlete dicts (SPEC.md §3). The OCR and
//  confirmation layer hands over numbers, so field aliases and "mm:ss.s" strings are not
//  needed; zero, negative and non-finite values are still rejected exactly as the Python does.
//

import Foundation

/// One logged session.
public struct SessionInput: Sendable, Equatable {
    /// Echoed back in the anchor so the UI can deep-link. Repeated ids are de-duplicated,
    /// keeping the last copy.
    public var id: String
    /// Read as a calendar day in the calendar passed to `PacePredictor.predict`.
    public var date: Date
    /// Total metres for the session.
    public var distanceM: Double
    public var tag: Tier.Name
    /// Total time in seconds. At least one of `timeS` / `splitS` is needed.
    public var timeS: Double?
    /// Average seconds per 500m.
    public var splitS: Double?
    /// Used for tag validation only.
    public var strokeRate: Double?
    /// Rep distance for interval sessions — the single biggest accuracy win (SPEC.md §7.3).
    public var repDistanceM: Double?
    /// Session RPE, Borg CR10 (0–10); Borg 6–20 values 11–20 are converted.
    public var rpe: Double?
    /// Bodyweight on the day, in kg.
    public var bodyweightKg: Double?

    public init(
        id: String,
        date: Date,
        distanceM: Double,
        tag: Tier.Name,
        timeS: Double? = nil,
        splitS: Double? = nil,
        strokeRate: Double? = nil,
        repDistanceM: Double? = nil,
        rpe: Double? = nil,
        bodyweightKg: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.distanceM = distanceM
        self.tag = tag
        self.timeS = timeS
        self.splitS = splitS
        self.strokeRate = strokeRate
        self.repDistanceM = repDistanceM
        self.rpe = rpe
        self.bodyweightKg = bodyweightKg
    }
}

/// The optional athlete profile. Drives the interpretation layer and the cold-start prior;
/// never alters an anchored prediction (SPEC.md §2.1).
public struct AthleteProfile: Sendable, Equatable {
    /// 5–110; outside that it is dropped with a warning.
    public var age: Double?
    /// The user's own answer. "male"/"female" are recognised; any other non-blank answer
    /// routes to the sex-neutral prior and still counts as a provided profile.
    public var sex: String?
    /// 25–250 kg; current bodyweight.
    public var weightKg: Double?

    public init(age: Double? = nil, sex: String? = nil, weightKg: Double? = nil) {
        self.age = age
        self.sex = sex
        self.weightKg = weightKg
    }
}
