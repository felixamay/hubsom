import { Suspense } from "react";
import ProfileEditorClient from "./ProfileEditorClient";

export default function ProfilePage() {
  return (
    <Suspense
      fallback={
        <div className="px-4 py-10 text-sm text-hubsom-ink/60">
          Loading profile…
        </div>
      }
    >
      <ProfileEditorClient />
    </Suspense>
  );
}
