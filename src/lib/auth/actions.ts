"use server";

import { AuthError } from "next-auth";
import { redirect } from "next/navigation";
import { signIn } from "@/auth";
import { createEmailUser } from "@/lib/data/users";

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export type AuthActionState = {
  error?: string;
};

async function establishSession(email: string, password: string) {
  try {
    await signIn("credentials", {
      email,
      password,
      redirect: false,
    });
  } catch (error) {
    if (error instanceof AuthError) {
      throw error;
    }
    // Some Auth.js versions still throw on success paths — ignore non-auth errors
    // unless they are real failures. Re-check by continuing to redirect.
    const dig = error as { type?: string; digest?: string };
    if (dig?.type === "AuthError" || String(dig?.digest ?? "").includes("AuthError")) {
      throw error;
    }
  }
}

export async function signInAction(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const email = normalizeEmail(String(formData.get("email") ?? ""));
  const password = String(formData.get("password") ?? "");
  const callbackUrl = String(formData.get("callbackUrl") ?? "/account");

  if (!email || !password) {
    return { error: "Email and password are required." };
  }

  try {
    await establishSession(email, password);
  } catch (error) {
    if (error instanceof AuthError) {
      return { error: "Invalid email or password." };
    }
    return { error: "Could not sign in. Please try again." };
  }

  redirect(callbackUrl.startsWith("/") ? callbackUrl : "/account");
}

export async function signUpAction(
  _prev: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const name = String(formData.get("name") ?? "").trim();
  const email = normalizeEmail(String(formData.get("email") ?? ""));
  const password = String(formData.get("password") ?? "");
  const callbackUrl = String(formData.get("callbackUrl") ?? "/account/profile");

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

  try {
    await establishSession(email, password);
  } catch {
    return {
      error: "Account created, but sign-in failed. Please sign in with your new password.",
    };
  }

  redirect(callbackUrl.startsWith("/") ? callbackUrl : "/account/profile");
}
