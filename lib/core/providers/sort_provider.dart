
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Sort {
  EXPIRY,
  DATE_ADDED,
  PRODUCT
}

class SortNotifier extends StateNotifier<Sort> {

  SortNotifier() : super(Sort.EXPIRY);

  Sort get sort => state;

  Sort toggle() {
    final newIndex = (state.index + 1) % Sort.values.length;
    state = Sort.values[newIndex];
    return state;
  }

  void setSort(Sort sort) {
    state = sort;
  }
}

final sortProvider = StateNotifierProvider<SortNotifier, Sort>((ref) => new SortNotifier());