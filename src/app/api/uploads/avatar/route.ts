import { randomBytes } from "crypto";
import { promises as fs } from "fs";
import path from "path";
import { NextResponse } from "next/server";
import { auth } from "@/auth";
import { ensureSellerForUser } from "@/lib/data/sellers";
import {
  getUserById,
  toPublicUser,
  updateUserProfile,
} from "@/lib/data/users";

export const runtime = "nodejs";

const MAX_BYTES = 5 * 1024 * 1024;
const ALLOWED = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["image/gif", "gif"],
]);

function uploadDir() {
  return path.join(process.cwd(), "public", "uploads", "avatars");
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return NextResponse.json({ error: "Invalid upload payload" }, { status: 400 });
  }

  const fileEntry = form.get("file");
  const file =
    fileEntry instanceof File && fileEntry.size > 0 ? fileEntry : null;
  if (!file) {
    return NextResponse.json({ error: "Choose a profile photo" }, { status: 400 });
  }

  const ext = ALLOWED.get(file.type);
  if (!ext) {
    return NextResponse.json(
      { error: "Use JPG, PNG, WEBP, or GIF" },
      { status: 400 },
    );
  }
  if (file.size > MAX_BYTES) {
    return NextResponse.json(
      { error: "Keep your photo under 5MB" },
      { status: 400 },
    );
  }

  await fs.mkdir(uploadDir(), { recursive: true });
  const buffer = Buffer.from(await file.arrayBuffer());
  const filename = `${session.user.id}-${Date.now().toString(36)}-${randomBytes(3).toString("hex")}.${ext}`;
  await fs.writeFile(path.join(uploadDir(), filename), buffer);
  const url = `/uploads/avatars/${filename}`;

  const current = await getUserById(session.user.id);
  if (!current) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  let sellerId = current.sellerId;
  if (sellerId || current.role === "seller" || current.role === "both") {
    const seller = await ensureSellerForUser({
      userId: current.id,
      name: current.name,
      city: current.city,
      region: current.region,
      bio: current.bio,
      avatar: url,
    });
    sellerId = seller.id;
  }

  const user = await updateUserProfile(session.user.id, {
    image: url,
    sellerId,
  });

  return NextResponse.json({
    url,
    user: user ? toPublicUser(user) : null,
  });
}
