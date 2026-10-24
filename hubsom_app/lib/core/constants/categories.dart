import 'package:flutter/material.dart';

class CategoryMeta {
  const CategoryMeta(this.slug, this.name, this.description, this.icon);
  final String slug;
  final String name;
  final String description;
  final IconData icon;
}

const hubsomCategories = <CategoryMeta>[
  CategoryMeta('groceries', 'Groceries', 'Fresh food and pantry staples', Icons.local_grocery_store_outlined),
  CategoryMeta('electronics', 'Electronics', 'Gadgets and devices', Icons.devices_outlined),
  CategoryMeta('fashion', 'Fashion', 'Clothing and apparel', Icons.checkroom_outlined),
  CategoryMeta('shoes', 'Shoes', 'Footwear for every style', Icons.directions_walk_outlined),
  CategoryMeta('beauty-personal-care', 'Beauty & Personal Care', 'Skincare and grooming', Icons.spa_outlined),
  CategoryMeta('health-wellness', 'Health & Wellness', 'Supplements and care', Icons.favorite_outline),
  CategoryMeta('home-kitchen', 'Home & Kitchen', 'Kitchen and home essentials', Icons.kitchen_outlined),
  CategoryMeta('furniture', 'Furniture', 'Home and office furniture', Icons.chair_outlined),
  CategoryMeta('home-decor', 'Home Decor', 'Decor and accents', Icons.light_outlined),
  CategoryMeta('appliances', 'Appliances', 'Home appliances', Icons.microwave_outlined),
  CategoryMeta('phones-accessories', 'Phones & Accessories', 'Phones and accessories', Icons.smartphone_outlined),
  CategoryMeta('computers-tablets', 'Computers & Tablets', 'Laptops and tablets', Icons.laptop_outlined),
  CategoryMeta('gaming', 'Gaming', 'Games and consoles', Icons.sports_esports_outlined),
  CategoryMeta('cameras-photography', 'Cameras & Photography', 'Cameras and gear', Icons.photo_camera_outlined),
  CategoryMeta('jewelry-watches', 'Jewelry & Watches', 'Jewelry and timepieces', Icons.watch_outlined),
  CategoryMeta('luxury-goods', 'Luxury Goods', 'Premium brands', Icons.diamond_outlined),
  CategoryMeta('baby-kids', 'Baby & Kids', 'Baby and kids essentials', Icons.child_friendly_outlined),
  CategoryMeta('toys-games', 'Toys & Games', 'Toys and games', Icons.toys_outlined),
  CategoryMeta('sports-outdoors', 'Sports & Outdoors', 'Sporting goods', Icons.sports_soccer_outlined),
  CategoryMeta('automotive', 'Automotive', 'Car parts and accessories', Icons.build_outlined),
  CategoryMeta('tools-hardware', 'Tools & Hardware', 'Tools and hardware', Icons.handyman_outlined),
  CategoryMeta('pet-supplies', 'Pet Supplies', 'Pet food and accessories', Icons.pets_outlined),
  CategoryMeta('books', 'Books', 'Books and reading', Icons.menu_book_outlined),
  CategoryMeta('music-instruments', 'Music & Instruments', 'Instruments and gear', Icons.music_note_outlined),
  CategoryMeta('movies-entertainment', 'Movies & Entertainment', 'Movies and media', Icons.movie_outlined),
  CategoryMeta('art-collectibles', 'Art & Collectibles', 'Art and collectibles', Icons.palette_outlined),
  CategoryMeta('antiques-vintage', 'Antiques & Vintage', 'Vintage finds', Icons.museum_outlined),
  CategoryMeta('handmade-crafts', 'Handmade Crafts', 'Handmade goods', Icons.volunteer_activism_outlined),
  CategoryMeta('office-school-supplies', 'Office & School', 'Office and school supplies', Icons.school_outlined),
  CategoryMeta('garden-outdoor', 'Garden & Outdoor', 'Garden and outdoor living', Icons.yard_outlined),
  CategoryMeta('industrial-business-equipment', 'Industrial & Business', 'Business equipment', Icons.precision_manufacturing_outlined),
  CategoryMeta('digital-products', 'Digital Products', 'Digital downloads', Icons.cloud_download_outlined),
  CategoryMeta('services', 'Services', 'Local services', Icons.miscellaneous_services_outlined),
  CategoryMeta('real-estate', 'Real Estate', 'Property listings', Icons.home_work_outlined),
  CategoryMeta('vehicles', 'Vehicles', 'Cars and vehicles', Icons.directions_car_outlined),
  CategoryMeta('tickets-events', 'Tickets & Events', 'Event tickets', Icons.confirmation_number_outlined),
  CategoryMeta('gift-cards', 'Gift Cards', 'Gift cards', Icons.card_giftcard_outlined),
  CategoryMeta('miscellaneous', 'Miscellaneous', 'Everything else', Icons.category_outlined),
];
