import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});
  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  bool _loading = false;
  String? _error;
  List<dynamic> _banners = [];

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  int _bannersReq = 0;
  Future<void> _fetchBanners() async {
    final r = ++_bannersReq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await ApiService.get('/admin/banners');
      if (!mounted || r != _bannersReq) return;
      final data = (res is Map && res['data'] is Map) ? res['data'] as Map : {};
      final list = (data['banners'] is List) ? (data['banners'] as List) : [];
      setState(() => _banners = list);
    } catch (e) {
      if (mounted && r == _bannersReq) setState(() => _error = '$e');
    } finally {
      if (mounted && r == _bannersReq) setState(() => _loading = false);
    }
  }

  void _showBannerDialog({Map? banner}) {
    final bool isEdit = banner != null;
    final titleCtrl = TextEditingController(text: banner?['title'] ?? '');
    final subtitleCtrl = TextEditingController(text: banner?['subtitle'] ?? '');
    final imageUrlCtrl = TextEditingController(text: banner?['imageUrl'] ?? '');
    final linkUrlCtrl = TextEditingController(text: banner?['linkUrl'] ?? '');
    String type = banner?['type'] ?? 'banner';
    int priority = banner?['priority'] ?? 10;
    bool isActive = banner?['isActive'] ?? true;
    final messenger = ScaffoldMessenger.of(context);

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: Text(isEdit ? 'Edit Banner / Event' : 'Create New Banner / Event'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SizedBox(
              width: math.min(520, MediaQuery.sizeOf(context).width * 0.95),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title (Required, 2-80 characters)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Subtitle / Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Image URL (Must start with https://)',
                      hintText: 'https://example.com/banner.png',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linkUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Click Redirect Link (Optional https://)',
                      hintText: 'https://example.com/promo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'banner', child: Text('Regular Banner')),
                          DropdownMenuItem(value: 'event', child: Text('Tournament / Event')),
                        ],
                        onChanged: (v) => setDState(() => type = v ?? 'banner'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$priority',
                        decoration: const InputDecoration(labelText: 'Priority (0-100)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => priority = int.tryParse(v) ?? 10,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active and visible to players'),
                    value: isActive,
                    onChanged: (v) => setDState(() => isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final img = imageUrlCtrl.text.trim();
                      if (title.length < 2 || title.length > 80) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Title must be between 2 and 80 characters'), backgroundColor: kRed),
                        );
                        return;
                      }
                      if (!img.startsWith('https://')) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Image URL must start with https://'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSubmitting = true);
                      final payload = <String, dynamic>{
                        'title': title,
                        if (subtitleCtrl.text.trim().isNotEmpty) 'subtitle': subtitleCtrl.text.trim(),
                        'imageUrl': img,
                        if (linkUrlCtrl.text.trim().isNotEmpty) 'linkUrl': linkUrlCtrl.text.trim(),
                        'type': type,
                        'priority': priority,
                        'isActive': isActive,
                      };

                      try {
                        if (isEdit) {
                          await ApiService.patch('/admin/banners/${banner['id'] ?? banner['_id']}', payload);
                        } else {
                          await ApiService.post('/admin/banners', payload);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(isEdit ? 'Banner updated successfully' : 'Banner created successfully'), backgroundColor: kGreen),
                          );
                          _fetchBanners();
                        }
                      } catch (e) {
                        setDState(() => isSubmitting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to save banner: $e'), backgroundColor: kRed),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEdit ? 'Save Changes' : 'Create Banner'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteBanner(Map banner) {
    final messenger = ScaffoldMessenger.of(context);
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Delete Banner?'),
          content: Text('Are you sure you want to permanently delete "${banner['title']}"?'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kRed),
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDState(() => isDeleting = true);
                      try {
                        await ApiService.delete('/admin/banners/${banner['id'] ?? banner['_id']}');
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Banner deleted successfully'), backgroundColor: kGreen),
                          );
                          _fetchBanners();
                        }
                      } catch (e) {
                        setDState(() => isDeleting = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: kRed),
                          );
                        }
                      }
                    },
              child: isDeleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Text(
                'Banners & In-Game Marketing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showBannerDialog(),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Create New Banner'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List
        card(
          'Active Campaigns (${_banners.length})',
          _loading
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Center(
                      child: Column(children: [
                        Text('Error loading banners: $_error', style: const TextStyle(color: kRed)),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _fetchBanners, child: const Text('Retry')),
                      ]),
                    )
                  : _banners.isEmpty
                      ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No banners found. Click "+ Create New Banner" to add one.')))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('PREVIEW')),
                              DataColumn(label: Text('TITLE')),
                              DataColumn(label: Text('TYPE')),
                              DataColumn(label: Text('PRIORITY')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('ACTIONS')),
                            ],
                            rows: [
                              for (var i = 0; i < _banners.length; i++)
                                DataRow(cells: [
                                  DataCell(Text('${i + 1}')),
                                  DataCell(
                                    Container(
                                      width: 60,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _banners[i]['imageUrl'] != null
                                          ? Image.network(
                                              _banners[i]['imageUrl'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 18, color: Colors.grey),
                                            )
                                          : const Icon(Icons.image, size: 18),
                                    ),
                                  ),
                                  DataCell(Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('${_banners[i]['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      if (_banners[i]['subtitle'] != null)
                                        Text('${_banners[i]['subtitle']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  )),
                                  DataCell(statusChip('${_banners[i]['type'] ?? 'banner'}')),
                                  DataCell(Text('${_banners[i]['priority'] ?? 0}')),
                                  DataCell(statusChip(_banners[i]['isActive'] == false ? 'Inactive' : 'Active')),
                                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: kBlue),
                                      tooltip: 'Edit Banner',
                                      onPressed: () => _showBannerDialog(banner: _banners[i]),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: kRed),
                                      tooltip: 'Delete Banner',
                                      onPressed: () => _confirmDeleteBanner(_banners[i]),
                                    ),
                                  ])),
                                ]),
                            ],
                          ),
                        ),
        ),
      ]),
    );
  }
}
