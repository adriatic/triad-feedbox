# Feedbox: design brief (version 1, 2026-11-12)

This text is part of the app's definition. It is the text given to the design tool to draw the screens, and it stays in the repository so a reader can redraw them.

## What Feedbox is
Feedbox is a free, open-source feedback and roadmap board for small products. Each product gets a public board where people post ideas and vote on them. The owner moves ideas through planned, building and shipped, and publishes a changelog.

## Who uses it
- **Visitors** read the board, sign in by magic link (an email address, no password), post an idea and upvote ideas. One vote per person per idea.
- **The owner** of a board changes an idea's status, merges duplicates, hides spam and writes changelog entries.

## Example board used in every screen
Product: "Lumen", a small note-taking app (invented, generic). Never show anything from pact-web.
Example ideas: "Dark mode for the editor" (214 votes, Planned), "Export notes to Markdown" (187, Building), "Keyboard shortcut cheat sheet" (96, Shipped), "Sync between two laptops" (73, Open), "Tag notes by colour" (41, Open).

## Screens to draw (desktop width 1280 px, and one phone width 390 px for the board)
1. **Board** (the main screen). Header with the product name and a Sign in button. A prominent "Post an idea" button. Tabs: Open, Planned, Building, Shipped. A list of ideas, each with a vote button and count on the left, the title, a one-line description, a status chip and a comment count. A search box and a sort control (Top, New).
2. **Idea detail.** Title, description, vote button, status chip, the comments, a comment box. Owner only: a status dropdown and a Merge button.
3. **Post an idea.** A short form: title, details, and a live list of similar existing ideas shown beneath the title as the visitor types, so duplicates are avoided.
4. **Sign in.** One field for an email address and a Send me a link button, then a second state that reads "Check your email".
5. **Changelog.** A dated list of shipped ideas, newest first, each linking back to its idea.

## Look and feel
Calm and quick to read, like a good developer tool. Plenty of white space. One accent colour, used for votes and the main button. Status chips in four distinct colours that also differ in label, so colour is never the only signal. Works in light and dark. Type sizes readable on a phone. No stock photos; small line icons only.

## Rules the design must keep
- The vote button is the most prominent thing in every row.
- Every screen shows which signed-in state it is in (visitor, signed in, owner).
- Every status chip uses the exact words Open, Planned, Building, Shipped.
- All text is real, specific text from the example board. No lorem ipsum.
