Markdown Editor
====

See <http://keshiki.net/markdown-editor/> for a more detailed
description.

To Build: you need to get a copy of OgreKit. I'm using v2.1.4 from
<http://web.me.com/oasis/ogrekit/Downloads.html>. Eventually I'll
include it in the repository, but not yet.

OgreKit needs to be in the same directory as the project folder (NOT
the project itself), so if `MarkEdit.xcodeproj` is in
`/Users/bodhi/Code/MarkEdit`, then OgreKit should be in
`/Users/bodhi/Code/OgreKit_2_1_4`. If you have it somewhere else, you'll need
to delete the reference to OgreKit in the Xcode project, and re-add
it. Then, you have to drag the OgreKit.framework (probably first one
in the project list, there are 2) to the "Copy Files" phase of the
MarkEdit application target.

Things to work on
----

* An automated tests suite
* Editing around inline images was very buggy, but it seems I've ironed out most of the bugs with it.
* Strong spans `**` nested in emphasis spans `*` aren't picked up
* Implicitly nested lists aren't highlighted correctly
* Lists with multiple paragraphs aren't always picked up properly
* Automatic indentation doesn't work well on hard-wrapped paragraphs
* The cursor sometimes gets drawn in the wrong place when deleting text. I think this has something to do with me making the wrong sequence of calls to manage the NSTextView system.
* Making the code easier to understand.

---

Thanks for your interest in this project! To contact me, send me a message on GitHub, [on Twitter](http://twitter.com/bodhi) or [send me an email](mailto:markdown@keshiki.net)