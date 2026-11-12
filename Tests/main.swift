import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
let lines = LyricsManager.parse("[offset:-100]\n[00:01.05][01:02.125]Hello\n[00:00.100]Start\n[ar:Someone]\n[00:99.00]Invalid\n[00:03]♪")
check(lines.count == 4, "Multi timestamps and invalid metadata")
check(abs(lines[0].timestamp) < 0.001, "Millisecond offset")
check(abs(lines[1].timestamp - 0.95) < 0.001, "Hundredths precision")
check(abs(lines[3].timestamp - 62.025) < 0.001, "Milliseconds precision")
check(lines[1].text == "Hello" && lines[3].text == "Hello", "Repeated text")
check(LyricsManager.parse("plain lyrics").isEmpty, "Unsynchronized lyrics")
check(LyricsManager.parse("[00:01.5]A")[0].timestamp == 1.5, "Tenths precision")
check(LyricsManager.parse("[00:01]A\n[00:01]B").map(\.text) == ["A", "B"], "Stable duplicate ordering")
check(LyricsManager.parse("[offset:+250]\n[00:00.000]早安")[0].text == "早安", "Unicode lyrics")
print("Lyrics parser checks passed")
