import 'package:flutter/material.dart';

import '../location/hdc_location_catalog.dart';

class HdcLocationPicker extends StatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final String? helperText;
  final bool required;
  final Key? regionKey;
  final Key? areaKey;

  const HdcLocationPicker({
    required this.value,
    required this.onChanged,
    this.label = 'Location',
    this.helperText,
    this.required = true,
    this.regionKey,
    this.areaKey,
    super.key,
  });

  @override
  State<HdcLocationPicker> createState() => _HdcLocationPickerState();
}

class _HdcLocationPickerState extends State<HdcLocationPicker> {
  String? _region;
  String? _area;

  @override
  void initState() {
    super.initState();
    _readValue();
  }

  @override
  void didUpdateWidget(covariant HdcLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _readValue();
  }

  void _readValue() {
    final parsed = HdcLocationCatalog.parseCanonical(widget.value);
    _region = parsed?.region;
    _area = parsed?.area;
  }

  void _emit() {
    final region = _region;
    final area = _area;
    if (region == null || area == null) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      HdcLocationSelection(region: region, area: area).canonical,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRegion = HdcLocationCatalog.regionByName(_region);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: widget.regionKey,
          initialValue: _region,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: '${widget.label} region',
            helperText: widget.helperText,
            prefixIcon: const Icon(Icons.map_outlined),
          ),
          items: HdcLocationCatalog.regions
              .map(
                (region) => DropdownMenuItem<String>(
                  value: region.name,
                  child: Text(region.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            setState(() {
              _region = value;
              _area = null;
            });
            _emit();
          },
          validator: widget.required
              ? (value) => value == null ? 'Choose a region.' : null
              : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: widget.areaKey,
          initialValue: selectedRegion?.areas.contains(_area) == true
              ? _area
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Province / independent city',
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
          items: (selectedRegion?.areas ?? const <String>[])
              .map(
                (area) => DropdownMenuItem<String>(
                  value: area,
                  child: Text(area, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: selectedRegion == null
              ? null
              : (value) {
                  setState(() => _area = value);
                  _emit();
                },
          validator: widget.required
              ? (value) => value == null ? 'Choose a province or city.' : null
              : null,
        ),
      ],
    );
  }
}

class HdcRegionPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final bool required;

  const HdcRegionPicker({
    required this.value,
    required this.onChanged,
    this.label = 'Region',
    this.required = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = HdcLocationCatalog.regionByName(value)?.name;
    return DropdownButtonFormField<String>(
      initialValue: normalized,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.map_outlined),
      ),
      items: HdcLocationCatalog.regions
          .map(
            (region) => DropdownMenuItem<String>(
              value: region.name,
              child: Text(region.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
      validator: required
          ? (value) => value == null ? 'Choose a region.' : null
          : null,
    );
  }
}
