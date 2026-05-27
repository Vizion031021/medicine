import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sseudeuson/theme/app_colors.dart';

class BagData {
  final String id;
  final String name;
  final int colorIndex;

  const BagData({
    required this.id,
    required this.name,
    this.colorIndex = 0,
  });

  Color get color {
    final index = colorIndex.clamp(0, AppColors.bagColors.length - 1).toInt();
    return AppColors.bagColors[index];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorIndex': colorIndex,
      };

  factory BagData.fromJson(Map<String, dynamic> json) {
    return BagData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      colorIndex: json['colorIndex'] is int ? json['colorIndex'] as int : 0,
    );
  }
}

class BagService {
  static const _bagsKey = 'medicine_bags';
  static const _assignmentsKey = 'medicine_bag_assignments';
  static const _defaultBag = BagData(id: 'default', name: '내 약봉투');

  static Future<List<BagData>> getBags() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bagsKey);
    final bags = <BagData>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          bags.addAll(
            decoded
                .whereType<Map>()
                .map(
                  (item) => BagData.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((bag) => bag.id.isNotEmpty && bag.name.isNotEmpty),
          );
        }
      } catch (_) {
        await prefs.remove(_bagsKey);
      }
    }

    final hasDefault = bags.any((bag) => bag.id == _defaultBag.id);
    if (!hasDefault) bags.insert(0, _defaultBag);
    return bags;
  }

  static Future<Map<String, String>> getAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_assignmentsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      await prefs.remove(_assignmentsKey);
      return {};
    }
  }

  static Future<void> assignMedication(String medicationId, String bagId) async {
    if (medicationId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final assignments = await getAssignments();
    assignments[medicationId] = bagId.isEmpty ? _defaultBag.id : bagId;
    await prefs.setString(_assignmentsKey, jsonEncode(assignments));
  }

  static Future<void> addBag(String name, int colorIndex) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final bags = await getBags();
    bags.add(
      BagData(
        id: 'bag_${DateTime.now().microsecondsSinceEpoch}',
        name: trimmed,
        colorIndex: colorIndex,
      ),
    );
    await _saveBags(prefs, bags);
  }

  static Future<void> removeBag(String bagId) async {
    if (bagId.isEmpty || bagId == _defaultBag.id) return;

    final prefs = await SharedPreferences.getInstance();
    final bags = await getBags();
    final filtered = bags.where((bag) => bag.id != bagId).toList();
    await _saveBags(prefs, filtered);

    final assignments = await getAssignments();
    assignments.updateAll(
      (_, currentBagId) => currentBagId == bagId ? _defaultBag.id : currentBagId,
    );
    await prefs.setString(_assignmentsKey, jsonEncode(assignments));
  }

  static Future<void> _saveBags(
    SharedPreferences prefs,
    List<BagData> bags,
  ) async {
    final normalized = <BagData>[];
    if (!bags.any((bag) => bag.id == _defaultBag.id)) {
      normalized.add(_defaultBag);
    }
    normalized.addAll(
      bags.where((bag) => bag.id.isNotEmpty && bag.name.isNotEmpty),
    );
    await prefs.setString(
      _bagsKey,
      jsonEncode(normalized.map((bag) => bag.toJson()).toList()),
    );
  }
}
