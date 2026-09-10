import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/kaolack_places.dart';
import '../../core/constants/yobalema_theme.dart';
import '../../core/models/commune.dart';

class PassengerSearchModal extends StatefulWidget {
  final String title;
  final Commune? currentSelection;

  const PassengerSearchModal({
    super.key,
    required this.title,
    this.currentSelection,
  });

  static Future<Commune?> show(
    BuildContext context, {
    required String title,
    Commune? current,
  }) {
    return showModalBottomSheet<Commune>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PassengerSearchModal(
        title: title,
        currentSelection: current,
      ),
    );
  }

  @override
  State<PassengerSearchModal> createState() => _PassengerSearchModalState();
}

class _PassengerSearchModalState extends State<PassengerSearchModal> {
  static const String allDepartmentsLabel = 'Tous';
  static const List<String> departments = [
    allDepartmentsLabel,
    'Kaolack',
    'Nioro du Rip',
    'Guinguinéo',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedDepartment = allDepartmentsLabel;
  List<Commune> _results = const [];

  String? get _departmentFilter =>
      _selectedDepartment == allDepartmentsLabel ? null : _selectedDepartment;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshResults);
    _refreshResults();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshResults)
      ..dispose();
    super.dispose();
  }

  void _refreshResults() {
    final filteredResults = KaolackPlaces.search(
      _searchController.text,
      department: _departmentFilter,
    );

    if (!mounted) return;
    setState(() => _results = filteredResults);
  }

  void _selectDepartment(String department) {
    if (_selectedDepartment == department) return;

    setState(() {
      _selectedDepartment = department;
      _results = KaolackPlaces.search(
        _searchController.text,
        department: _departmentFilter,
      );
    });
  }

  IconData _iconForZone(ZoneType zone) {
    switch (zone) {
      case ZoneType.city:
        return Icons.location_city;
      case ZoneType.periurban:
        return Icons.storefront;
      default:
        return Icons.terrain;
    }
  }

  String _subtitleFor(Commune place) {
    final description = place.description.isEmpty
        ? ''
        : ' • ${place.description}';
    return 'Département de ${place.department}$description';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = math.max(
      0.0,
      mediaQuery.size.height - mediaQuery.viewInsets.bottom,
    );
    final modalHeight = math.min(
      mediaQuery.size.height * 0.85,
      availableHeight,
    ).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: modalHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Semantics(
            label: 'Faire glisser pour fermer',
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: YobalemaTheme.ink,
                        ),
                      ),
                      const Text(
                        'Région de Kaolack • Motos Yobalema',
                        style: TextStyle(
                          fontSize: 12,
                          color: YobalemaTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Fermer la recherche',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          _SearchField(controller: _searchController),

          const SizedBox(height: 10),

          // Department Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: departments.map((department) {
                final isSelected = _selectedDepartment == department;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      department == allDepartmentsLabel
                          ? 'Toute la région'
                          : 'Dép. $department',
                    ),
                    selected: isSelected,
                    selectedColor: YobalemaTheme.primary,
                    checkmarkColor: YobalemaTheme.ink,
                    labelStyle: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: YobalemaTheme.ink,
                    ),
                    onSelected: (_) => _selectDepartment(department),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 20),

          // Results list
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun lieu trouvé dans la région de Kaolack.\nEssayez un nom de quartier ou de commune.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: YobalemaTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _results[index];
                      final isCurrent = widget.currentSelection == place;

                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isCurrent
                              ? YobalemaTheme.primary
                              : YobalemaTheme.surface,
                          child: Icon(
                            _iconForZone(place.zone),
                            color: YobalemaTheme.ink,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          place.name,
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w900 : FontWeight.w700,
                            color: YobalemaTheme.ink,
                          ),
                        ),
                        subtitle: Text(
                          _subtitleFor(place),
                          style: const TextStyle(
                            fontSize: 12,
                            color: YobalemaTheme.textMuted,
                          ),
                        ),
                        trailing: isCurrent
                            ? const Icon(Icons.check_circle,
                                color: YobalemaTheme.green)
                            : const Icon(Icons.arrow_forward_ios,
                                size: 14, color: Colors.grey),
                          onTap: () => Navigator.of(context).pop(place),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}



class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Rechercher un quartier, village, commune, marché...',
              prefixIcon: const Icon(Icons.search, color: YobalemaTheme.ink),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: 'Effacer la recherche',
                      onPressed: controller.clear,
                    ),
            ),
          );
        },
      ),
    );
  }
}
