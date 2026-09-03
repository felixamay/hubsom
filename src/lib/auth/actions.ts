"use server";

import { AuthError } from "next-auth";
import { signIn } from "@/auth";
import { createEmailUser } from "@/lib/data/users";

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function safeCallback(path: string, fallback: string) {
  return path.startsWith("/") ? path : fallback;
}

export type AuthActionState = {
  error?: string;
};

export async function signInAction(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = normalizeEmail(String(formData.get("email") ?? ""));
  const password = String(formData.get("password") ?? "");
  const callbackUrl = safeCallback(
    String(formData.get("callbackUrl") ?? "/"),
    "/",
  );

  if (!email || !password) {
    return { error: "Email and password are required." };
  }

  try {
    // Sets the session cookie and redirects — do not catch NEXT_REDIRECT.
    await signIn("credentials", {
      email,
      password,
      redirectTo: callbackUrl,
    });
    return {};
  } catch (error) {
    if (error instanceof AuthError) {
      return { error: "Invalid email or password." };
    }
    throw error;
  }
}

export async function signUpAction(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const name = String(formData.get("name") ?? "").trim();
  const email = normalizeEmail(String(formData.get("email") ?? ""));
  const password = String(formData.get("password") ?? "");
  const callbackUrl = safeCallback(
    String(formData.get("callbackUrl") ?? "/"),
    "/",
  );

  if (!name) return { error: "Please enter your full name." };
  if (!email || !email.includes("@")) {
    return { error: "Please enter a valid email address." };
  }
  if (password.length < 8) {
    return { error: "Password must be at least 8 characters." };
  }

  try {
    await createEmailUser({ name, email, password });
  } catch (error) {
    return {
      error: error instanceof Error ? error.message : "Could not create account.",
    };
  }

  const afterSignup =
    callbackUrl === "/"
      ? "/account/profile?welcome=1"
      : `/account/profile?welcome=1&next=${encodeURIComponent(callbackUrl)}`;

  try {
    await signIn("credentials", {
      email,
      password,
      redirectTo: afterSignup,
    });
    return {};
  } catch (error) {
    if (error instanceof AuthError) {
      return {
        error:
          "Account created, but sign-in failed. Please sign in with your new password.",
      };
    }
    throw error;
  }
}
