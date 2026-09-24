# Browser Guide to macOS Handoff

**Status:** normative local setup contract; installed Launch Services behavior
and accessibility require separate acceptance evidence.

The optional guide handoff is a navigation hint to the installed Mac app. It
has no authority to pair, select a target, import content, queue delivery, or
change credentials. A deep link may come from any local app or website, so it
is never treated as proof of the public guide's origin.

## Versioned URL

The sole admitted shape is
`frameshift://setup?v=1&class=<paper|photo|pixel>&profile=<id>`. `profile`
may be omitted. The app registers `frameshift` through `CFBundleURLTypes` and
receives URLs with AppKit's application delegate. The entire URL is at most
512 UTF-8 bytes. Scheme and host must be lowercase, the path empty, and
userinfo, port, and fragment absent. Exactly one `v` and `class` are required;
`profile` may occur once. Unknown or duplicate query keys are refused.

The version is exactly `1`. Class values are the three lowercase reference
names. A supplied profile ID contains 1–128 ASCII characters from letters,
digits, `.`, `_`, `:`, and `-`; it is a hint that must be checked against the
actual paired frame capability. Percent decoding does not relax that grammar.
The URL cannot contain an image, instruction, path, token, identity, address,
command name, or automatic action. Invalid URLs are discarded without
including their bytes in an operational log or alert.

## Native behavior

The shell keeps one accepted guide choice in memory and shows its class and
optional profile in the menu panel. The user can dismiss it. A matching
already-paired target may be selected only by an explicit button press through
the authenticated local command path; the candidate's class and exact
advertised profile ID must both match. If no target matches, the shell
explains that pairing remains a native, physical-mode action. Opening the link
never initiates pairing or calls the frame network directly. Restart drops
the hint.

The public guide may create the link after the user chooses a class. It labels
the action as opening an installed app, and does not imply installation or
physical compatibility. Signed installation and real pairing are separate
release gates. See [browser simulation](../architecture/guide-simulation.md).

Apple documents `CFBundleURLTypes` and
[`application(_:open:)`](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/application%28_%3Aopen%3A%29)
for Mac URL delivery.
