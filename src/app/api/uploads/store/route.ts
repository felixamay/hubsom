import { randomBytes } from "crypto";
import { promises as fs } from "fs";
import path from "path";
import { NextResponse } from "next/server";
import { auth } from "@/auth";
import {
  ensureSellerForUser,
  updateSeller,
} from "@/lib/data/sellers";
import { getUserById, updateUserProfile } from "@/lib/data/users";

export const runtime = "nodejs";

const MAX_BYTES = 5 * 1024 * 1024;
const ALLOWED = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"],
  ["image/gif", "gif"],
]);

function uploadDir() {
  return path.join(process.cwd(), "public", "uploads", "store");
}

export async function POST(request: Request) {
  const session = await auth();
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Sign in required" }, { status: 401 });
  }

  const user = await getUserById(session.user.id);
  if (!user) {
    return NextResponse.json({ error: "User not found" }, { status: 404 });
  }

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return NextResponse.json({ error: "Invalid upload payload" }, { status: 400 });
  }

  const kindRaw = String(form.get("kind") ?? "avatar");
  const kind = kindRaw === "cover" ? "cover" : "avatar";
  const fileEntry = form.get("file");
  const file =
    fileEntry instanceof File && fileEntry.size > 0 ? fileEntry : null;
  if (!file) {
    return NextResponse.json(
      { error: kind === "cover" ? "Choose a cover photo" : "Choose a store photo" },
      { status: 400 },
    );
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
      { error: "Keep images under 5MB" },
      { status: 400 },
    );
  }

  await fs.mkdir(uploadDir(), { recursive: true });
  const buffer = Buffer.from(await file.arrayBuffer());
  const filename = `${user.id}-${kind}-${Date.now().toString(36)}-${randomBytes(3).toString("hex")}.${ext}`;
  await fs.writeFile(path.join(uploadDir(), filename), buffer);
  const url = `/uploads/store/${filename}`;

  const seller = await ensureSellerForUser({
    userId: user.id,
    name: user.name,
    city: user.city,
    region: user.region,
    bio: user.bio,
    avatar: user.image,
  });

  if (user.sellerId !== seller.id) {
    await updateUserProfile(user.id, {
      sellerId: seller.id,
      role: user.role === "buyer" ? "both" : user.role,
    });
  }

  const updated = await updateSeller(seller.id, {
    [kind]: url,
  });

  return NextResponse.json({ url, kind, seller: updated });
}
