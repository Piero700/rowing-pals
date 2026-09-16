//
//  DismissKeyboardOnTap.swift
//  Rowing Pals
//

import SwiftUI

extension View {
    /// Tapping anywhere on this view that isn't already a control (a
    /// button, a text field itself) resigns the keyboard — the standard
    /// "tap empty space to dismiss" behaviour, applied per-screen since
    /// SwiftUI sheets and full-screen covers are separate presentation
    /// contexts from whatever screen presented them and don't inherit a
    /// modifier applied to the root.
    func dismissesKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
