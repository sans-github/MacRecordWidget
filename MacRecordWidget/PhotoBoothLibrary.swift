import AppKit
import Foundation
import os

let libraryLog = Logger(subsystem: "com.macrecordwidget", category: "photobooth")

/// Writes movies into Photo Booth's library so they appear in its filmstrip.
///
/// The library is an undocumented store and everything here was established by
/// measurement, not documentation. See the "Photo Booth library" section of
/// CLAUDE.md before changing any of it.
enum PhotoBoothLibrary {

    /// Where Photo Booth keeps the actual media. A plain folder, not a package:
    /// the `.mov` and `.jpg` files sit directly inside it.
    static var picturesDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Photo Booth Library", isDirectory: true)
            .appendingPathComponent("Pictures", isDirectory: true)
    }

    /// **This file is the filmstrip index, not a "recently viewed" list.**
    ///
    /// Measured 2026-09-09: with three valid `.mov` files on disk and this
    /// array empty, Photo Booth showed nothing at all. Recording one movie
    /// added exactly one entry here and exactly one thumbnail. That
    /// measurement also concluded unlisted files are ignored; the current
    /// Photo Booth recovers them instead (see `addToFilmstrip`).
    static var recentsPlist: URL {
        picturesDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Recents.plist")
    }

    static let photoBoothBundleID = "com.apple.PhotoBooth"

    /// True while Photo Booth is running, which is the one case where the app
    /// must not write `Recents.plist`.
    static var isPhotoBoothRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: photoBoothBundleID).isEmpty
    }

    // MARK: - Naming

    /// A free URL matching Photo Booth's own naming, e.g.
    /// `Movie on 9-9-26 at 2.26 PM.mov`.
    ///
    /// The separator before AM/PM is **U+202F NARROW NO-BREAK SPACE**, not a
    /// plain space. Every file Photo Booth has written on this machine uses it
    /// (verified by hex dump), and a name built with an ASCII space is a
    /// different filename. It is written into the format string literally
    /// rather than left to the locale, so the output cannot drift with an OS
    /// update that changes CLDR's time pattern.
    static func availableMovieURL(for date: Date = Date()) -> URL {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "'Movie on 'M-d-yy' at 'h.mm\u{202F}a"
        let base = formatter.string(from: date)

        let directory = picturesDirectory
        var candidate = directory.appendingPathComponent(base).appendingPathExtension("mov")

        // Photo Booth's naming resolves only to the minute, so a second
        // recording inside the same minute collides. Suffix rather than
        // overwrite: losing a recording the user just made is the worst
        // available outcome.
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(base) \(counter)")
                .appendingPathExtension("mov")
            counter += 1
        }
        return candidate
    }

    /// Creates the library's `Pictures` folder if it is missing, so a machine
    /// that has never run Photo Booth still gets its recordings saved.
    static func ensurePicturesDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: picturesDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Index

    /// Filenames waiting to be added to / removed from `Recents.plist`,
    /// persisted so a relaunch of this app does not lose them.
    private static let pendingAddsKey = "photoBooth.pendingAdds"
    private static let pendingRemovalsKey = "photoBooth.pendingRemovals"

    /// Adds a finished movie to Photo Booth's filmstrip, now or as soon as
    /// Photo Booth quits.
    ///
    /// **An unindexed movie is not ignored, it is "recovered".** Photo Booth's
    /// launch pass (`PBAssetCollectionDidRecoverOrphanedMoviesNotification`,
    /// read from its disassembly 2026-10-20) treats any `.mov` in `Pictures/`
    /// that is missing from this array as an orphan, indexes it itself and
    /// shows "A movie was recovered". Leaving the movie unindexed while Photo
    /// Booth was running is what produced that alert, so the write is queued
    /// rather than dropped.
    static func addToFilmstrip(_ url: URL) {
        enqueue(url.lastPathComponent, key: pendingAddsKey, cancelling: pendingRemovalsKey)
    }

    /// Drops a trashed movie from the filmstrip, now or as soon as Photo Booth
    /// quits, so the index never lists a file that is gone.
    static func removeFromFilmstrip(_ url: URL) {
        guard url.deletingLastPathComponent().standardizedFileURL
            == picturesDirectory.standardizedFileURL else { return }
        enqueue(url.lastPathComponent, key: pendingRemovalsKey, cancelling: pendingAddsKey)
    }

    /// Applies queued changes when Photo Booth quits. Call once at launch.
    ///
    /// Photo Booth holds its own copy of the array in memory and rewrites the
    /// file on quit, so writing underneath it would either be clobbered or
    /// clobber its entries. `didTerminate` fires after the process has exited,
    /// so its rewrite has already landed.
    static func startSyncing() {
        guard quitObserver == nil else { return }
        quitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == photoBoothBundleID else { return }
            flushPending()
        }
        flushPending()
    }

    private static var quitObserver: NSObjectProtocol?

    private static func enqueue(_ filename: String, key: String, cancelling other: String) {
        let defaults = UserDefaults.standard
        var queue = defaults.stringArray(forKey: key) ?? []
        queue.removeAll { $0 == filename }
        queue.append(filename)
        defaults.set(queue, forKey: key)
        defaults.set((defaults.stringArray(forKey: other) ?? []).filter { $0 != filename }, forKey: other)
        flushPending()
    }

    /// Writes every queued change in one pass. Does nothing while Photo Booth
    /// is running; the queue survives until the next attempt.
    private static func flushPending() {
        let defaults = UserDefaults.standard
        let adds = defaults.stringArray(forKey: pendingAddsKey) ?? []
        let removals = defaults.stringArray(forKey: pendingRemovalsKey) ?? []
        guard !adds.isEmpty || !removals.isEmpty else { return }
        guard !isPhotoBoothRunning else {
            libraryLog.notice("Photo Booth is running, \(adds.count + removals.count, privacy: .public) filmstrip change(s) wait for it to quit")
            return
        }

        let original = readRecents()
        var names = original.filter { !removals.contains($0) }
        // Oldest first, each to index 0: Photo Booth puts the newest first.
        // A file trashed before the flush must not be indexed.
        for filename in adds where !names.contains(filename)
            && FileManager.default.fileExists(atPath: picturesDirectory.appendingPathComponent(filename).path) {
            names.insert(filename, at: 0)
        }

        if names != original {
            // XML, not binary. Photo Booth writes this file as XML and there
            // is no reason to hand it a format it has never produced itself.
            do {
                let data = try PropertyListSerialization.data(fromPropertyList: names, format: .xml, options: 0)
                try data.write(to: recentsPlist, options: .atomic)
            } catch {
                libraryLog.error("cannot write Recents.plist: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        libraryLog.notice("filmstrip updated: \(adds.count, privacy: .public) added, \(removals.count, privacy: .public) removed")
        defaults.removeObject(forKey: pendingAddsKey)
        defaults.removeObject(forKey: pendingRemovalsKey)
    }

    private static func readRecents() -> [String] {
        guard let data = try? Data(contentsOf: recentsPlist),
              let plist = try? PropertyListSerialization.propertyList(
                  from: data, options: [], format: nil
              ),
              let names = plist as? [String]
        else { return [] }
        return names
    }
}
