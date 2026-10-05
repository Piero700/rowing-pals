# Speed and smoothness — test checklist

No migration. Branch `t37-performance`. Best felt on the **Staging** build, which is optimised
(the Debug build Xcode runs by default is not, and is always slower):
1. In Xcode, click the scheme name **Rowing Pals** next to the ▶︎ button → **Edit Scheme…**.
2. **Run** in the left list → **Info** tab → **Build Configuration: Staging**, and untick
   **Debug executable**. **Close**, then **⌘R** to run on your phone.
3. Afterwards set it back to **Debug** the same way.

## 1. Loading
- [ ] Open the app. The feed's posts appear noticeably sooner than before; photos follow.
- [ ] Switch to **Rankings** and **Profile**: their numbers are already there or arrive almost at
      once (they now share what the feed already fetched about you).
- [ ] **Rankings → Test results**: the gold "Best in your group" cards hold their place while
      loading (dim placeholders), and the grid below **doesn't jump**.
- [ ] Open a workout that was a test: the gold banner fills in quickly.

## 2. Photos are remembered
- [ ] Scroll the feed so a few photos load. Pull down to refresh: the photos stay put — no
      grey placeholders flashing back.
- [ ] Close the app fully (swipe it away), turn on **Aeroplane mode**, reopen: photos you'd
      already seen still show. Turn Aeroplane mode off.

## 3. Animations
- [ ] Tap between **Feed**, **Rankings** and **Profile**: the screen changes instantly; only
      the bar's highlight slides. No half-second blend of two screens.
- [ ] Scroll a feed with a new-PB post (rainbow edge): scrolling stays smooth and the colours
      still run around the edge.
- [ ] iPhone **Settings → Accessibility → Motion → Reduce Motion** on: the rainbow edge stops
      moving (colours stay still). Turn it back off.

## 4. Still up to date
- [ ] Join or leave a club (or have an admin accept you): Feed, Rankings and Profile all show
      the new club straight away.
- [ ] Follow someone: their posts appear under **Feed → Following** after pulling to refresh.
- [ ] Ask to follow a private rower and have them accept on their phone: pull to refresh and
      their posts appear (or wait two minutes).

## 5. One fix to check
- [ ] **Feed → Following** ("You and people you follow") now includes **your own** posts too.
      Before, it only ever showed the people you follow.
