import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ui/hdc_colors.dart';
import '../../models/account_identity.dart';
import '../../models/product_listing.dart';
import '../../providers/hdc_sales_center_provider.dart';

const _categories = <String, String>{
  'computers': 'Desktop computers',
  'laptops': 'Laptops',
  'mobile_devices': 'Mobile devices',
  'pos_equipment': 'POS and business equipment',
  'networking': 'Networking',
  'parts_components': 'Parts and components',
  'accessories': 'Accessories and peripherals',
  'software_licenses': 'Software and licenses',
  'other_technology': 'Other technology',
};

class ProductListingEditScreen extends StatefulWidget {
  final ProductListing? listing;

  const ProductListingEditScreen({
    this.listing,
    super.key,
  });

  @override
  State<ProductListingEditScreen> createState() =>
      _ProductListingEditScreenState();
}

class _ProductListingEditScreenState
    extends State<ProductListingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  HDCPlatformRole? _sellerRole;
  String _categoryCode = 'other_technology';
  ProductItemCondition _condition = ProductItemCondition.used;
  bool _submitting = false;

  ProductListing? get _listing => widget.listing;
  bool get _editing => _listing != null;

  @override
  void initState() {
    super.initState();
    final listing = _listing;
    _titleController = TextEditingController(text: listing?.title ?? '');
    _descriptionController = TextEditingController(
      text: listing?.description ?? '',
    );
    _priceController = TextEditingController(
      text: listing == null
          ? ''
          : '${listing.unitPriceMinor ~/ 100}.${(listing.unitPriceMinor % 100).toString().padLeft(2, '0')}',
    );
    _stockController = TextEditingController(
      text: listing?.stockQuantity.toString() ?? '1',
    );
    _sellerRole = listing?.sellerRole;
    _categoryCode = listing?.categoryCode ?? _categoryCode;
    _condition = listing?.condition ?? _condition;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sellerRole != null) return;
    final profiles = context.read<HdcSalesCenterProvider>().sellingProfiles;
    if (profiles.isNotEmpty) _sellerRole = profiles.first.role;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit(ProductListingStatus status) async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final sellerRole = _sellerRole;
    final unitPriceMinor = _priceMinor(_priceController.text);
    final stockQuantity = int.tryParse(_stockController.text.trim());
    if (sellerRole == null || unitPriceMinor == null || stockQuantity == null) {
      _showError('Check the selling profile, price, and stock quantity.');
      return;
    }
    if (status == ProductListingStatus.active && stockQuantity < 1) {
      _showError('A published listing needs at least one item in stock.');
      return;
    }

    final body = <String, Object?>{
      'sellerRole': sellerRole.code,
      'categoryCode': _categoryCode,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'condition': _condition.code,
      'currency': 'PHP',
      'unitPriceMinor': unitPriceMinor,
      'stockQuantity': stockQuantity,
      'status': status.code,
      if (_listing != null) 'version': _listing!.version,
    };

    setState(() => _submitting = true);
    try {
      final provider = context.read<HdcSalesCenterProvider>();
      if (_listing == null) {
        await provider.createListing(body);
      } else {
        await provider.updateListing(_listing!.id, body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.watch<HdcSalesCenterProvider>().sellingProfiles;
    final editableStatus = _listing?.status ?? ProductListingStatus.draft;

    return Scaffold(
      backgroundColor: HDCColors.background,
      appBar: AppBar(
        title: Text(_editing ? 'Edit Item Listing' : 'List a Technology Item'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NoticeCard(editing: _editing),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<HDCPlatformRole>(
                      initialValue: _sellerRole,
                      decoration: const InputDecoration(
                        labelText: 'Selling workspace',
                        border: OutlineInputBorder(),
                      ),
                      items: profiles
                          .map(
                            (profile) => DropdownMenuItem(
                              value: profile.role,
                              child: Text(
                                '${profile.publicName} • ${profile.role.label}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _sellerRole = value),
                      validator: (value) => value == null
                          ? 'Choose an approved selling workspace.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _categoryCode,
                      decoration: const InputDecoration(
                        labelText: 'Technology category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.entries
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.key,
                              child: Text(item.value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(
                                () => _categoryCode = value ?? _categoryCode,
                              ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      enabled: !_submitting,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Item title',
                        hintText: 'Example: Refurbished Lenovo ThinkPad',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final length = value?.trim().length ?? 0;
                        return length < 3 ? 'Enter a clear item title.' : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_submitting,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 4000,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'State specifications, included parts, defects, warranty, and fulfillment details.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().length ?? 0) < 10
                          ? 'Add an honest description of at least 10 characters.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<ProductItemCondition>(
                      initialValue: _condition,
                      decoration: const InputDecoration(
                        labelText: 'Condition',
                        border: OutlineInputBorder(),
                      ),
                      items: ProductItemCondition.values
                          .map(
                            (condition) => DropdownMenuItem(
                              value: condition,
                              child: Text(condition.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(
                                () => _condition = value ?? _condition,
                              ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            enabled: !_submitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Price (PHP)',
                              prefixText: '₱ ',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => _priceMinor(value ?? '') == null
                                ? 'Enter a valid price.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Available stock',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final stock = int.tryParse(value?.trim() ?? '');
                              if (stock == null || stock < 0 || stock > 1000000) {
                                return 'Enter a valid stock count.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_submitting)
                      const Center(child: CircularProgressIndicator())
                    else if (_editing)
                      FilledButton.icon(
                        onPressed: () => _submit(editableStatus),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Changes'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _submit(ProductListingStatus.draft),
                              icon: const Icon(Icons.drafts_outlined),
                              label: const Text('Save Draft'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _submit(ProductListingStatus.active),
                              icon: const Icon(Icons.sell_outlined),
                              label: const Text('Publish Item'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final bool editing;

  const _NoticeCard({required this.editing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined, color: HDCColors.info),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                editing
                    ? 'Changes are version-checked so another device cannot silently overwrite a newer listing.'
                    : 'Only technology-related, lawful, accurately described items may be listed. Images will be added after secure marketplace storage is activated.',
                style: const TextStyle(
                  color: HDCColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _priceMinor(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (!RegExp(r'^\d{1,10}(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null) return null;
  final decimalText = parts.length == 1 ? '00' : parts[1].padRight(2, '0');
  final decimal = int.tryParse(decimalText);
  if (decimal == null) return null;
  final result = whole * 100 + decimal;
  return result > 0 && result <= 999999999999 ? result : null;
}
