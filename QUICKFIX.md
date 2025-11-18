# Quick Fix Guide - Vanta Portrait

## 🔥 Critical Issue: Info.plist Build Error

**Error Message:**
```
The Copy Bundle Resources build phase contains this target's Info.plist file
'/Users/iandeuberry/Projects/Vanta Portrait/Vanta-Portrait-Info.plist'.
```

### Fix Steps (5 minutes):

1. **Open Xcode** and load your project
2. In the **Project Navigator** (left sidebar), select **Vanta Portrait** (the blue project icon at the top)
3. In the main editor, select the **Vanta Portrait** target (under TARGETS)
4. Click the **Build Phases** tab at the top
5. Find and expand **Copy Bundle Resources** section
6. Look for `Vanta-Portrait-Info.plist` in the list of files
7. Select it and click the **− (minus)** button to remove it
8. Press **⇧⌘K** (Shift-Command-K) to **Clean Build Folder**
9. Press **⌘B** (Command-B) to **Build**

### Why This Happens:
The Info.plist should **only** be referenced in Build Settings → Info.plist File, not copied as a bundle resource. Xcode sometimes accidentally adds it when files are dragged around.

---

## ✅ What I Fixed in Your Code

### 1. Thread Safety (CameraManager.swift)
**Changed:** Removed unsafe `@unchecked Sendable` wrapper
**Added:** Proper pixel buffer locking/unlocking

### 2. Race Conditions (CameraManager.swift)
**Added:** `NSLock` for thread-safe burst capture state management

### 3. Error Handling (PoseDetector.swift)
**Changed:** Silent `try?` to proper error handling with logging

### 4. Accessibility (ContentView.swift)
**Added:** VoiceOver labels, hints, and values throughout the UI

---

## 📊 File Access Status

✅ **I can now see ALL your files:**
- ✅ README.md (comprehensive!)
- ✅ AppViewModel.swift
- ✅ CameraManager.swift
- ✅ PoseDetector.swift
- ✅ GuidanceEngine.swift
- ✅ StabilityTracker.swift
- ✅ ContentView.swift
- ✅ ResultView.swift
- ✅ CameraPreviewView.swift
- ✅ DebugPanelView.swift
- ✅ CountdownOverlay.swift
- ✅ Vanta_PortraitApp.swift
- ✅ Test files

Your project structure is clean and well-organized!

---

## 🎯 Priority Recommendations

### Must Do (Today):
1. ⚠️ **Fix Info.plist build error** (see steps above)
2. ✅ Build and test the thread-safety fixes I made

### Should Do (This Week):
3. 🧪 Add unit tests for `GuidanceEngine` and `StabilityTracker`
4. ⚙️ Implement user preferences/settings window
5. 📋 Add "Copy to Clipboard" functionality

### Nice to Have (Later):
6. 🎨 Add grid overlay for composition
7. 📸 Implement photo history
8. 🔊 Add sound effects for countdown/capture
9. 📤 Add share sheet integration
10. 🎨 Visual feedback (pulse) when ready to capture

---

## 📝 Quick Testing Checklist

After fixing the Info.plist issue, test:
- [ ] App builds without errors
- [ ] Camera preview appears
- [ ] Face detection guidance works
- [ ] Strict/flexible modes toggle correctly
- [ ] Countdown appears when pose is good
- [ ] Burst capture completes
- [ ] Best frame is selected
- [ ] Save to Pictures works
- [ ] Debug panel displays metrics
- [ ] No crashes or hangs

---

## 🐛 Known Minor Issues

1. **Timer retain cycle potential** - Already using `[weak self]` correctly, but consider switching to Combine publishers
2. **No custom save location** - Currently hardcoded to Pictures folder
3. **Duplicate filenames** - Could overwrite existing files with same timestamp

See `CODE_REVIEW.md` for detailed solutions to these issues.

---

## 💬 Questions?

If you encounter any issues after making these changes:
1. Check the Console in Xcode for error messages
2. Review the `CODE_REVIEW.md` file for detailed explanations
3. Make sure all files compile without warnings

Good luck! Your app is really well-built. 🚀
