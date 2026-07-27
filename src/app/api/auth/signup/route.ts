import { NextResponse } from "next/server";
import { createEmailUser, toPublicUser } from "@/lib/data/users";

export async function POST(request: Request) {
  const body = (await request.json()) as {
    name?: string;
    email?: string;
    password?: string;
  };

  try {
    const user = await createEmailUser({
      name: body.name?.trim() || "",
      email: body.email ?? "",
      password: body.password ?? "",
    });
    return NextResponse.json({ user: toPublicUser(user) }, { status: 201 });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Signup failed" },
      { status: 400 },
    );
  }
}
