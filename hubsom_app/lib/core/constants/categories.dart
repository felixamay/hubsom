class CategoryMeta {
  const CategoryMeta(this.slug, this.name, this.description);
  final String slug;
  final String name;
  final String description;
}

const hubsomCategories = <CategoryMeta>[
  CategoryMeta('groceries', 'Groceries', 'Fresh food and pantry staples'),
  CategoryMeta('electronics', 'Electronics', 'Gadgets and devices'),
  CategoryMeta('fashion', 'Fashion', 'Clothing and apparel'),
  CategoryMeta('shoes', 'Shoes', 'Footwear for every style'),
  CategoryMeta('beauty-personal-care', 'Beauty & Personal Care', 'Skincare and grooming'),
  CategoryMeta('health-wellness', 'Health & Wellness', 'Supplements and care'),
  CategoryMeta('home-kitchen', 'Home & Kitchen', 'Kitchen and home essentials'),
  CategoryMeta('furniture', 'Furniture', 'Home and office furniture'),
  CategoryMeta('home-decor', 'Home Decor', 'Decor and accents'),
  CategoryMeta('appliances', 'Appliances', 'Home appliances'),
  CategoryMeta('phones-accessories', 'Phones & Accessories', 'Phones and accessories'),
  CategoryMeta('computers-tablets', 'Computers & Tablets', 'Laptops and tablets'),
  CategoryMeta('gaming', 'Gaming', 'Games and consoles'),
  CategoryMeta('cameras-photography', 'Cameras & Photography', 'Cameras and gear'),
  CategoryMeta('jewelry-watches', 'Jewelry & Watches', 'Jewelry and timepieces'),
  CategoryMeta('luxury-goods', 'Luxury Goods', 'Premium brands'),
  CategoryMeta('baby-kids', 'Baby & Kids', 'Baby and kids essentials'),
  CategoryMeta('toys-games', 'Toys & Games', 'Toys and games'),
  CategoryMeta('sports-outdoors', 'Sports & Outdoors', 'Sporting goods'),
  CategoryMeta('automotive', 'Automotive', 'Car parts and accessories'),
  CategoryMeta('tools-hardware', 'Tools & Hardware', 'Tools and hardware'),
  CategoryMeta('pet-supplies', 'Pet Supplies', 'Pet food and accessories'),
  CategoryMeta('books', 'Books', 'Books and reading'),
  CategoryMeta('music-instruments', 'Music & Instruments', 'Instruments and gear'),
  CategoryMeta('movies-entertainment', 'Movies & Entertainment', 'Movies and media'),
  CategoryMeta('art-collectibles', 'Art & Collectibles', 'Art and collectibles'),
  CategoryMeta('antiques-vintage', 'Antiques & Vintage', 'Vintage finds'),
  CategoryMeta('handmade-crafts', 'Handmade Crafts', 'Handmade goods'),
  CategoryMeta('office-school-supplies', 'Office & School', 'Office and school supplies'),
  CategoryMeta('garden-outdoor', 'Garden & Outdoor', 'Garden and outdoor living'),
  CategoryMeta('industrial-business-equipment', 'Industrial & Business', 'Business equipment'),
  CategoryMeta('digital-products', 'Digital Products', 'Digital downloads'),
  CategoryMeta('services', 'Services', 'Local services'),
  CategoryMeta('real-estate', 'Real Estate', 'Property listings'),
  CategoryMeta('vehicles', 'Vehicles', 'Cars and vehicles'),
  CategoryMeta('tickets-events', 'Tickets & Events', 'Event tickets'),
  CategoryMeta('gift-cards', 'Gift Cards', 'Gift cards'),
  CategoryMeta('miscellaneous', 'Miscellaneous', 'Everything else'),
];
