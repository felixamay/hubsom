import '../../models/product.dart';
import '../../models/promotion.dart';
import '../../models/seller.dart';
import '../../models/stream.dart';

/// Offline / no-API catalog so Firebase Hosting works before the Hubsom API
/// is deployed. Replaced automatically when `/api/products` responds.
abstract final class DemoCatalog {
  static const sellers = <Seller>[
    Seller(
      id: 'seller-accra-mart',
      slug: 'accra-mart',
      name: 'Accra Mart',
      city: 'Accra',
      region: 'Greater Accra',
      bio: 'Everyday essentials delivered across Accra.',
      avatar: '',
      cover: '',
      rating: 4.7,
      followers: 1280,
      verified: true,
      categories: ['groceries', 'home-kitchen'],
    ),
    Seller(
      id: 'seller-kumasi-live',
      slug: 'kumasi-live',
      name: 'Kumasi Live Fits',
      city: 'Kumasi',
      region: 'Ashanti',
      bio: 'Fashion drops and live shopping from Kumasi.',
      avatar: '',
      cover: '',
      rating: 4.8,
      followers: 3420,
      verified: true,
      categories: ['fashion', 'shoes'],
    ),
  ];

  static final products = <Product>[
    Product(
      id: 'demo-rice-5kg',
      slug: 'royal-rice-5kg',
      name: 'Royal Aromatic Rice 5kg',
      description: 'Premium long-grain rice for Ghanaian kitchens.',
      category: 'groceries',
      priceGhs: 95,
      compareAtGhs: 120,
      images: const [],
      sellerId: 'seller-accra-mart',
      stock: 40,
      rating: 4.6,
      reviewCount: 88,
      tags: const ['pantry', 'staples'],
      supports: const ['buy-now', 'store-listing'],
    ),
    Product(
      id: 'demo-kente-scarf',
      slug: 'handwoven-kente-scarf',
      name: 'Handwoven Kente Scarf',
      description: 'Bold kente scarf — live-auction favourite.',
      category: 'fashion',
      priceGhs: 180,
      images: const [],
      sellerId: 'seller-kumasi-live',
      stock: 12,
      rating: 4.9,
      reviewCount: 41,
      tags: const ['kente', 'handmade'],
      supports: const ['buy-now', 'live-selling', 'live-auction'],
    ),
    Product(
      id: 'demo-blender',
      slug: 'power-blender-pro',
      name: 'Power Blender Pro',
      description: 'Smoothies, soups, and banku batter ready.',
      category: 'appliances',
      priceGhs: 450,
      compareAtGhs: 520,
      images: const [],
      sellerId: 'seller-accra-mart',
      stock: 8,
      rating: 4.4,
      reviewCount: 26,
      tags: const ['kitchen'],
      flashSale: const FlashSale(endsAt: '2099-12-31T23:59:59Z', discountPct: 15),
      supports: const ['buy-now', 'flash-sale'],
    ),
    Product(
      id: 'demo-sneakers',
      slug: 'accra-runner-sneakers',
      name: 'Accra Runner Sneakers',
      description: 'Lightweight sneakers for city miles.',
      category: 'shoes',
      priceGhs: 320,
      images: const [],
      sellerId: 'seller-kumasi-live',
      stock: 20,
      rating: 4.5,
      reviewCount: 63,
      tags: const ['sneakers'],
      supports: const ['buy-now', 'live-selling'],
    ),
    Product(
      id: 'demo-shea',
      slug: 'pure-shea-butter-500ml',
      name: 'Pure Shea Butter 500ml',
      description: 'Unrefined shea from Northern Ghana.',
      category: 'beauty-personal-care',
      priceGhs: 55,
      images: const [],
      sellerId: 'seller-accra-mart',
      stock: 100,
      rating: 4.8,
      reviewCount: 210,
      tags: const ['shea', 'skin'],
      supports: const ['buy-now', 'store-listing'],
    ),
    Product(
      id: 'demo-phone-case',
      slug: 'shockproof-phone-case',
      name: 'Shockproof Phone Case',
      description: 'Clear armour case for popular Android phones.',
      category: 'phones-accessories',
      priceGhs: 45,
      images: const [],
      sellerId: 'seller-kumasi-live',
      stock: 75,
      rating: 4.2,
      reviewCount: 19,
      tags: const ['accessories'],
      supports: const ['buy-now', 'live-selling'],
    ),
  ];

  static final promotions = <Promotion>[
    const Promotion(
      id: 'promo-welcome',
      title: 'Welcome to Hubsom',
      subtitle: 'Buy now · Live shopping · Auctions — Ghana’s marketplace',
      placement: 'landing',
      priority: 10,
    ),
    const Promotion(
      id: 'promo-flash',
      title: 'Flash deals this week',
      subtitle: 'Limited stock on appliances and fashion',
      href: '/flash-sales',
      placement: 'marketplace',
      priority: 5,
    ),
  ];

  static final streams = <LiveStream>[
    LiveStream(
      id: 'demo-live-1',
      title: 'Kumasi Friday Fits — Live',
      description: 'Sneakers, scarves, and drops with pinned products.',
      sellerId: 'seller-kumasi-live',
      status: 'live',
      channelName: 'hubsom-demo-1',
      cover: '',
      viewerCount: 128,
      peakViewers: 210,
      productIds: const ['demo-sneakers', 'demo-kente-scarf'],
      pinnedProductId: 'demo-kente-scarf',
      categories: const ['fashion', 'shoes'],
      auction: const LiveAuction(
        id: 'auction-kente',
        productId: 'demo-kente-scarf',
        startingBidGhs: 100,
        currentBidGhs: 145,
        minIncrementGhs: 10,
        endsAt: '2099-12-31T23:59:59Z',
        bidderCount: 7,
        status: 'open',
      ),
    ),
  ];

  static List<Product> productsFiltered({String? category, String? q, String? sellerId}) {
    var list = [...products];
    if (category != null && category.isNotEmpty) {
      list = list.where((p) => p.category == category).toList();
    }
    if (sellerId != null && sellerId.isNotEmpty) {
      list = list.where((p) => p.sellerId == sellerId).toList();
    }
    if (q != null && q.trim().isNotEmpty) {
      final needle = q.trim().toLowerCase();
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(needle) ||
                p.description.toLowerCase().contains(needle) ||
                p.tags.any((t) => t.toLowerCase().contains(needle)),
          )
          .toList();
    }
    return list;
  }
}
