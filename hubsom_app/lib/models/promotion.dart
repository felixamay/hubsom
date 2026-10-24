import 'package:equatable/equatable.dart';

class Promotion extends Equatable {
  const Promotion({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.href,
    required this.placement,
    this.categorySlugs = const [],
    this.productIds = const [],
    this.active = true,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? href;
  final String placement; // landing | marketplace | category | product
  final List<String> categorySlugs;
  final List<String> productIds;
  final bool active;
  final int priority;

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        imageUrl: json['imageUrl'] as String? ?? json['image'] as String?,
        href: json['href'] as String? ?? json['link'] as String?,
        placement: json['placement'] as String? ?? 'landing',
        categorySlugs: (json['categorySlugs'] as List?)?.cast<String>() ?? const [],
        productIds: (json['productIds'] as List?)?.cast<String>() ?? const [],
        active: json['active'] as bool? ?? true,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, title, placement, priority];
}
