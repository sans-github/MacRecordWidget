import AppKit
import Foundation

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
    /// added exactly one entry here and exactly one thumbnail. Files present on
    /// disk but absent from this array are ignored entirely -- neither shown
    /// nor deleted.
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

    /// Adds a finished movie to Photo Booth's filmstrip.
    ///
    /// Returns whether the index was updated. `false` means the movie was left
    /// on disk but will not appear in Photo Booth, which is deliberate: if
    /// Photo Booth is running it holds its own copy of this array in memory and
    /// rewrites the file on quit, so writing underneath it would either be
    /// clobbered or clobber Photo Booth's own entries.
    @discardableResult
    static func addToFilmstrip(_ url: URL) -> Bool {
        guard !isPhotoBoothRunning else { return false }

        var names = readRecents()
        let filename = url.lastPathComponent
        names.removeAll { $0 == filename }
        // Index 0: Photo Booth puts the newest entry first.
        names.insert(filename, at: 0)

        // XML, not binary. Photo Booth writes this file as XML and there is no
        // reason to hand it a format it has never produced itself.
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: names,
            format: .xml,
            options: 0
        ) else { return false }

        do {
            try data.write(to: recentsPlist, options: .atomic)
            return true
        } catch {
            return false
        }
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
