import Link from "next/link";
import { MESSAGE_WORDS } from "@/lib/messages/core";
import { getBoard, getViewer } from "@/lib/supabase/data";
import { ContactForm } from "./ContactForm";

// Contact the owner (task CT1): a message to the board's owners, stored in the
// database and read on /messages. No email is sent. Only signed-in people can
// send one (decision (a) of task CT1).
export default async function ContactPage() {
  const board = await getBoard();
  if (!board) {
    return (
      <main className="page">
        <h1 className="page-title">Board not found</h1>
      </main>
    );
  }
  const viewer = await getViewer(board.id);
  return (
    <main className="page page-narrow-top contact-page">
      <Link href="/" className="back-link">
        &larr; All ideas
      </Link>
      <h1 className="page-title">{MESSAGE_WORDS.pageTitle}</h1>
      {viewer.role === "visitor" ? (
        <>
          <p>Only signed-in people can send a message to the owner of {board.name}.</p>
          <div>
            <Link href="/sign-in?next=%2Fcontact" className="btn btn-primary">
              {MESSAGE_WORDS.signInLink}
            </Link>
          </div>
        </>
      ) : (
        <>
          <p className="muted">Write to the owner of {board.name}, for example to ask a question or to ask to be removed.</p>
          <ContactForm />
        </>
      )}
    </main>
  );
}
