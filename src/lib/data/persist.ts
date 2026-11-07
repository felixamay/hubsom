import { randomBytes } from "crypto";
import { promises as fs } from "fs";
import path from "path";

const tails = new Map<string, Promise<unknown>>();

export function getDataDir(): string {
  const override = process.env.HUBSOM_DATA_DIR?.trim();
  if (override) return override;
  return path.join(process.cwd(), ".data");
}

/** Serialize async work per key so JSON read-modify-write cannot drop updates. */
export function withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
  const prev = tails.get(key) ?? Promise.resolve();
  const next = prev.then(fn, fn);
  tails.set(
    key,
    next.then(
      () => undefined,
      () => undefined,
    ),
  );
  return next;
}

async function writeAtomic(file: string, data: unknown): Promise<void> {
  await fs.mkdir(path.dirname(file), { recursive: true });
  const tmp = `${file}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
  await fs.writeFile(tmp, JSON.stringify(data, null, 2), "utf8");
  await fs.rename(tmp, file);
}

export async function readJsonFile<T>(filename: string, fallback: T): Promise<T> {
  const file = path.join(getDataDir(), filename);
  try {
    const raw = await fs.readFile(file, "utf8");
    return JSON.parse(raw) as T;
  } catch (error) {
    const missing =
      error !== null &&
      typeof error === "object" &&
      "code" in error &&
      (error as { code?: string }).code === "ENOENT";
    if (!missing) throw error;
    await writeAtomic(file, fallback);
    return fallback;
  }
}

export async function writeJsonFile<T>(filename: string, data: T): Promise<void> {
  await writeAtomic(path.join(getDataDir(), filename), data);
}

/**
 * Locked read → mutate → write for a JSON document.
 * If `mutate` throws, the file is left unchanged.
 */
export async function mutateJsonFile<T>(
  filename: string,
  fallback: T,
  mutate: (data: T) => void | T | Promise<void | T>,
): Promise<T> {
  return withLock(filename, async () => {
    const data = await readJsonFile(filename, fallback);
    const result = await mutate(data);
    const next = (result === undefined ? data : result) as T;
    await writeJsonFile(filename, next);
    return next;
  });
}

export function slugify(input: string): string {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80);
}
