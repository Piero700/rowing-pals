//
//  PresentationPlace.swift
//  Rowing Pals
//

import Foundation

/// Where a view sits, as `PresentationProbe` reads it from UIKit: the presentation it belongs to
/// (identified by that presentation's top view controller) and whether it was pushed onto a
/// navigation stack rather than being that stack's first screen.
struct PresentationPlace: Equatable {
    let presentation: ObjectIdentifier
    let isPushed: Bool
}
