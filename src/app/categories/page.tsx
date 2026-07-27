import type { Metadata } from "next";
import { CategoriesBrowse } from "@/components/categories/CategoriesBrowse";

export const metadata: Metadata = {
  title: "Categories",
  description:
    "Browse every Hubsom product category — Buy Now, live, auction, flash.",
};

export default function CategoriesPage() {
  return <CategoriesBrowse />;
}
