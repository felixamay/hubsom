import { writeFile, mkdir } from "fs/promises";
import path from "path";

// Cohesive transparent Icons8 3D Fluency set (PNG with alpha).
const ICONS = {
  groceries: "https://img.icons8.com/3d-fluency/600/ingredients.png",
  electronics: "https://img.icons8.com/3d-fluency/600/electronics.png",
  fashion: "https://img.icons8.com/3d-fluency/600/clothes.png",
  shoes: "https://img.icons8.com/3d-fluency/600/sneakers.png",
  "beauty-personal-care": "https://img.icons8.com/3d-fluency/600/lipstick.png",
  "health-wellness": "https://img.icons8.com/3d-fluency/600/heart-with-pulse.png",
  "home-kitchen": "https://img.icons8.com/3d-fluency/600/kitchen.png",
  furniture: "https://img.icons8.com/3d-fluency/600/sofa.png",
  "home-decor": "https://img.icons8.com/3d-fluency/600/lamp.png",
  appliances: "https://img.icons8.com/3d-fluency/600/washing-machine.png",
  "phones-accessories": "https://img.icons8.com/3d-fluency/600/iphone-x.png",
  "computers-tablets": "https://img.icons8.com/3d-fluency/600/laptop.png",
  gaming: "https://img.icons8.com/3d-fluency/600/controller.png",
  "cameras-photography": "https://img.icons8.com/3d-fluency/600/camera.png",
  "jewelry-watches": "https://img.icons8.com/3d-fluency/600/apple-watch.png",
  "luxury-goods": "https://img.icons8.com/3d-fluency/600/handbag.png",
  "baby-kids": "https://img.icons8.com/3d-fluency/600/baby.png",
  "toys-games": "https://img.icons8.com/3d-fluency/600/teddy-bear.png",
  "sports-outdoors": "https://img.icons8.com/3d-fluency/600/basketball.png",
  automotive: "https://img.icons8.com/3d-fluency/600/car.png",
  "tools-hardware": "https://img.icons8.com/3d-fluency/600/toolbox.png",
  "pet-supplies": "https://img.icons8.com/3d-fluency/600/dog.png",
  books: "https://img.icons8.com/3d-fluency/600/book.png",
  "music-instruments": "https://img.icons8.com/3d-fluency/600/guitar.png",
  "movies-entertainment": "https://img.icons8.com/3d-fluency/600/movie-projector.png",
  "art-collectibles": "https://img.icons8.com/3d-fluency/600/paint-palette.png",
  "antiques-vintage": "https://img.icons8.com/3d-fluency/600/grandfather-clock.png",
  "handmade-crafts": "https://img.icons8.com/3d-fluency/600/yarn.png",
  "office-school-supplies": "https://img.icons8.com/3d-fluency/600/stationery.png",
  "garden-outdoor": "https://img.icons8.com/3d-fluency/600/potted-plant.png",
  "industrial-business-equipment": "https://img.icons8.com/3d-fluency/600/factory.png",
  "digital-products": "https://img.icons8.com/3d-fluency/600/cloud-download.png",
  services: "https://img.icons8.com/3d-fluency/600/handshake.png",
  "real-estate": "https://img.icons8.com/3d-fluency/600/home.png",
  vehicles: "https://img.icons8.com/3d-fluency/600/motorcycle.png",
  "tickets-events": "https://img.icons8.com/3d-fluency/600/ticket.png",
  "gift-cards": "https://img.icons8.com/3d-fluency/600/gift-card.png",
  miscellaneous: "https://img.icons8.com/3d-fluency/600/shopping-bag.png",
};

const root = path.resolve("public/categories");
await mkdir(root, { recursive: true });

for (const [slug, url] of Object.entries(ICONS)) {
  try {
    const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 Hubsom/1.0" } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const buf = Buffer.from(await res.arrayBuffer());
    // Icons8 sometimes returns SVG/HTML on miss — ensure PNG signature
    if (buf[0] !== 0x89 || buf[1] !== 0x50) {
      throw new Error(`Not a PNG (${buf.slice(0, 16).toString("utf8").slice(0, 40)})`);
    }
    await writeFile(path.join(root, `${slug}.png`), buf);
    console.log("ok", slug, `${Math.round(buf.length / 1024)}kb`);
  } catch (e) {
    console.error("fail", slug, e.message);
  }
}
