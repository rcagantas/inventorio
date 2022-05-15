
import 'package:flutter/foundation.dart';
import 'package:inventorio/core/models/app_user.dart';
import 'package:inventorio/core/models/item.dart';
import 'package:inventorio/core/models/meta.dart';
import 'package:inventorio/core/models/product.dart';

@immutable
class AppState {
  final AppUser user;
  final Map<String, Meta> metas;
  final Map<String, Product> globalProductMap;
  final Map<String, Product> localProductMap;
  final Map<String, Item> items;

  AppState({
    required this.user,
    required this.metas,
    required this.globalProductMap,
    required this.localProductMap,
    required this.items
  });

  AppState.clone(AppState other) : this(
    user: other.user,
    metas: other.metas,
    globalProductMap: other.globalProductMap,
    localProductMap: other.localProductMap,
    items: other.items
  );
}