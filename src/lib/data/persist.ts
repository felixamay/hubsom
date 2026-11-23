import { promises as fs } from "fs";
import path from "path";

function dataDir() {
  return path.join(process.cwd(), ".data");
}

export async function readJsonFile<T>(filename: string, fallback: T): Promise<T> {
  const file = path.join(dataDir(), filename);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as T;
  } catch {
    await fs.mkdir(dataDir(), { recursive: true });
    await fs.writeFile(file, JSON.stringify(fallback, null, 2), "utf8");
    return fallback;
  }
}

export async function writeJsonFile<T>(filename: string, data: T): Promise<void> {
  await fs.mkdir(dataDir(), { recursive: true });
  const file = path.join(dataDir(), filename);
  await fs.writeFile(file, JSON.stringify(data, null, 2), "utf8");
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}
