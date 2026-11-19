import { describe, expect, it } from "vitest";
import {
  checkMessage,
  cleanMessage,
  inboxLabel,
  inboxSummary,
  MESSAGE_MAX,
  MESSAGE_WORDS,
  MESSAGES_PER_HOUR,
  messageCounter,
  messageLength,
  replyHref,
  type InboxMessage,
} from "./core";
import { RATE_LIMITS } from "../feedbox";

describe("the messages part: rules", () => {
  it("allows 2000 characters, like the database", () => {
    expect(MESSAGE_MAX).toBe(2000);
  });

  it("allows 5 messages an hour, like the database's rate limit", () => {
    expect(MESSAGES_PER_HOUR).toBe(5);
    expect(RATE_LIMITS.message).toBe(MESSAGES_PER_HOUR);
  });

  it("counts characters as a person does: an emoji or an accented letter counts once", () => {
    expect(messageLength("héllo")).toBe(5);
    expect(messageLength("👍🏽")).toBe(2);
    expect(messageLength("📝")).toBe(1);
  });

  it("trims the message, so it never starts or ends with a space, tab or line break", () => {
    expect(cleanMessage("  \n Hello \t\n\n")).toBe("Hello");
    expect(cleanMessage("\r\nOne\r\nTwo  \r\n")).toBe("One\nTwo");
  });

  it("keeps line breaks inside, with at most one empty line in a row", () => {
    expect(cleanMessage("One\n\n\n\nTwo")).toBe("One\n\nTwo");
  });

  it("refuses an empty message in words", () => {
    expect(checkMessage("")).toEqual({ ok: false, reason: "Write your message first." });
    expect(checkMessage(" \n\t ")).toEqual({ ok: false, reason: "Write your message first." });
  });

  it("accepts 2000 characters and refuses 2001, after trimming", () => {
    expect(checkMessage("x".repeat(2000))).toEqual({ ok: true, value: "x".repeat(2000) });
    expect(checkMessage(`  ${"x".repeat(2000)}  `)).toEqual({ ok: true, value: "x".repeat(2000) });
    expect(checkMessage("x".repeat(2001))).toEqual({ ok: false, reason: "A message can have at most 2000 characters (now 2001)." });
  });

  it("counts 2000 emoji as 2000 characters", () => {
    expect(checkMessage("📝".repeat(2000)).ok).toBe(true);
  });
});

describe("the messages part: words on the screens", () => {
  it("names the links and buttons as Nik decided", () => {
    expect(MESSAGE_WORDS.footerLink).toBe("Contact the owner");
    expect(MESSAGE_WORDS.signInLink).toBe("Sign in to contact the owner");
    expect(MESSAGE_WORDS.label).toBe("Your message");
    expect(MESSAGE_WORDS.send).toBe("Send message");
    expect(MESSAGE_WORDS.sent).toBe("Your message was sent to the owner.");
    expect(MESSAGE_WORDS.shownToOwner).toBe(
      "The owner will see your name and the email address you sign in with, so they can answer you.",
    );
    expect(MESSAGE_WORDS.none).toBe("No messages yet.");
  });

  it("shows the counter as typed / allowed", () => {
    expect(messageCounter("")).toBe("0 / 2000");
    expect(messageCounter("Hi 👋")).toBe("4 / 2000");
  });

  it("labels the header link with the number of unread messages, only when there are any", () => {
    expect(inboxLabel(0)).toBe("Messages");
    expect(inboxLabel(1)).toBe("Messages (1)");
    expect(inboxLabel(2)).toBe("Messages (2)");
  });

  const message = (id: number, read: boolean): InboxMessage => ({
    id,
    body: "Hello",
    createdAt: "2026-11-19T10:00:00Z",
    read,
    senderName: "Sam",
    senderEmail: "sam@example.com",
  });

  it("sums up the Messages page in one sentence", () => {
    expect(inboxSummary([])).toBe("No messages yet.");
    expect(inboxSummary([message(1, true)])).toBe("1 message, all read.");
    expect(inboxSummary([message(1, false), message(2, true), message(3, false)])).toBe("3 messages, 2 not read yet.");
  });

  it("answers from the owner's own email with a mailto: link", () => {
    expect(replyHref(message(1, false), "Lumen")).toBe("mailto:sam@example.com?subject=Your%20message%20to%20Lumen");
    expect(replyHref({ senderEmail: null }, "Lumen")).toBeNull();
    expect(replyHref({ senderEmail: "a+b@example.com" }, "Lumen")).toBe("mailto:a%2Bb@example.com?subject=Your%20message%20to%20Lumen");
  });
});
