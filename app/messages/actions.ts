"use server";
import { revalidatePath } from "next/cache";
import { setMessageRead } from "@/lib/messages/data";

export type MarkState = { status: "idle" } | { status: "error"; message: string };

/** "Mark as read" and "Mark as unread" on /messages (owners only; the database checks). */
export async function markMessage(_prev: MarkState, form: FormData): Promise<MarkState> {
  const id = Number(form.get("message_id"));
  const read = form.get("read") === "1";
  const result = await setMessageRead(id, read);
  if (!result.ok) return { status: "error", message: result.reason };
  // The header's count of unread messages is on every page.
  revalidatePath("/", "layout");
  return { status: "idle" };
}
