import 'dart:collection';
import 'dart:typed_data';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../../crew/data/crew_repository.dart';
import '../../crew/models/crew_models.dart';
import 'crew_widgets.dart';
import 'package:crewning/utils/error_handler.dart';

Future<CrewSummary?> showCrewCreateDialog(
  BuildContext context, {
  required CrewRepository repository,
  required List<AreaOption> areas,
}) async {
  return showDialog<CrewSummary>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _CreateCrewDialog(
      repository: repository,
      areas: areas,
    ),
  );
}

class _CreateCrewDialog extends StatefulWidget {
  const _CreateCrewDialog({
    required this.repository,
    required this.areas,
  });

  final CrewRepository repository;
  final List<AreaOption> areas;

  @override
  State<_CreateCrewDialog> createState() => _CreateCrewDialogState();
}

class _CreateCrewDialogState extends State<_CreateCrewDialog> {
  final ImagePicker _picker = ImagePicker();

  Map<int, _AreaListEntry> _areaEntryById = {};
  Map<String, List<_AreaListEntry>> _groupedAreas = {};
  bool _areasLoading = false;

  String _crewName = '';
  final Set<int> _selectedAreaIds = {};
  String? _introduction;
  XFile? _selectedFile;
  Uint8List? _previewBytes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final grouped = _prepareAreaData(widget.areas);
    _groupedAreas = grouped.grouped;
    _areaEntryById = grouped.byId;
  }

  bool get _isValid {
    final trimmed = _crewName.trim();
    return trimmed.length >= 2 &&
        trimmed.length <= 10 &&
        _selectedAreaIds.isNotEmpty;
  }

  _GroupedAreaData _prepareAreaData(List<AreaOption> areas) {
    final grouped = <String, List<_AreaListEntry>>{};
    final byId = <int, _AreaListEntry>{};
    const seoulGroup = '서울시';

    for (final area in areas) {
      final entry = _AreaListEntry(area: area, childLabel: area.name);
      grouped.putIfAbsent(seoulGroup, () => []).add(entry);
      byId[area.areaId] = entry;
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) => a.childLabel.compareTo(b.childLabel));
    }

    final sorted = SplayTreeMap<String, List<_AreaListEntry>>.from(grouped);
    return _GroupedAreaData(sorted, byId);
  }

  Future<void> _pickImage() async {
    if (_submitting) return;
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final theme = Theme.of(context);
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '크루 로고 자르기',
          toolbarColor: theme.colorScheme.surface,
          toolbarWidgetColor: theme.colorScheme.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: '크루 로고 자르기',
          aspectRatioLockEnabled: true,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (cropped == null) return;

    final bytes = await cropped.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedFile = XFile(cropped.path);
      _previewBytes = bytes;
    });
  }

  void _removeArea(int areaId) {
    if (_submitting) return;
    setState(() {
      _selectedAreaIds.remove(areaId);
    });
  }

  Future<void> _onAreaButtonPressed() async {
    await _loadAreas(force: true);
    if (!mounted) return;
    if (_groupedAreas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록된 지역이 없습니다.')),
      );
      return;
    }
    final result = await showDialog<Set<int>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AreaSelectionDialog(
        groupedAreas: _groupedAreas,
        initialSelected: _selectedAreaIds,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedAreaIds
        ..clear()
        ..addAll(result.take(3));
    });
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() {
      _submitting = true;
    });
    try {
      String? logoUrl;
      if (_selectedFile != null) {
        logoUrl = await widget.repository.uploadCrewLogo(_selectedFile!);
      }
      final summary = await widget.repository.createCrew(
        crewName: _crewName.trim(),
        areaIds: (_selectedAreaIds.toList()..sort()),
        introduction: _introduction,
        logoUrl: logoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(summary);
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _loadAreas({bool force = false}) async {
    if (_areasLoading) return;
    if (!force && _groupedAreas.isNotEmpty) return;
    setState(() {
      _areasLoading = true;
    });
    try {
      final areas = await widget.repository.fetchAreas();
      if (!mounted) return;
      final grouped = _prepareAreaData(areas);
      setState(() {
        _groupedAreas = grouped.grouped;
        _areaEntryById = grouped.byId;
      });
    } catch (error) {
      if (!mounted) return;
      showError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _areasLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildNameField(),
                  const SizedBox(height: 12),
                  _buildLogoSection(),
                  const SizedBox(height: 20),
                  _buildAreaSection(),
                  const SizedBox(height: 20),
                  _buildIntroductionField(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '크루 생성',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      enabled: !_submitting,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: '크루명 (2~10자)',
      ),
      maxLength: 10,
      onChanged: (value) {
        setState(() {
          _crewName = value;
        });
      },
    );
  }

  Widget _buildLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '크루 로고',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 120,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: _previewBytes != null
                  ? Image.memory(
                      _previewBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : const Text('이미지 선택'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaSection() {
    final selectedEntries = _selectedAreaIds
        .map((id) => _areaEntryById[id])
        .whereType<_AreaListEntry>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '크루 활동 지역 (최대 3개)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (selectedEntries.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                child: const Text('선택된 지역이 없습니다.'),
              ),
            ...selectedEntries.map(
              (entry) => _SelectedAreaChip(
                label: entry.area.name,
                onRemove: () => _removeArea(entry.area.areaId),
              ),
            ),
            OutlinedButton.icon(
              onPressed:
                  (_submitting || _areasLoading) ? null : _onAreaButtonPressed,
              icon: _areasLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.map_outlined),
              label: Text(_areasLoading ? '불러오는 중...' : '지역 선택'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntroductionField() {
    return TextField(
      enabled: !_submitting,
      maxLines: null,
      maxLength: 100,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: '크루 한줄 소개 (선택)',
      ),
      onChanged: (value) {
        setState(() {
          _introduction = value.isEmpty ? null : value;
        });
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('취소'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isValid ? _submit : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: _isValid
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('확인'),
          ),
        ),
      ],
    );
  }
}

class _SelectedAreaChip extends StatelessWidget {
  const _SelectedAreaChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            InkWell(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaSelectionDialog extends StatefulWidget {
  const _AreaSelectionDialog({
    required this.groupedAreas,
    required this.initialSelected,
  });

  final Map<String, List<_AreaListEntry>> groupedAreas;
  final Set<int> initialSelected;

  @override
  State<_AreaSelectionDialog> createState() => _AreaSelectionDialogState();
}

class _AreaSelectionDialogState extends State<_AreaSelectionDialog> {
  late final List<String> _groups;
  late String? _activeGroup;
  late Set<int> _selectedIds;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _groups = widget.groupedAreas.keys.toList();
    _activeGroup = _groups.isEmpty ? null : _groups.first;
    _selectedIds = {...widget.initialSelected};
  }

  void _setGroup(String group) {
    setState(() {
      _activeGroup = group;
    });
  }

  void _toggleArea(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _errorMessage = null;
      } else if (_selectedIds.length < 3) {
        _selectedIds.add(id);
        _errorMessage = null;
      } else {
        _errorMessage = '최대 3개까지 선택할 수 있습니다.';
      }
    });
  }

  void _confirm() {
    Navigator.of(context).pop(<int>{..._selectedIds});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SizedBox(
        width: 520,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '활동 지역 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _groups.isEmpty
                  ? const Center(child: Text('등록된 지역이 없습니다.'))
                  : Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: ListView.builder(
                            itemCount: _groups.length,
                            itemBuilder: (context, index) {
                              final group = _groups[index];
                              final selected = group == _activeGroup;
                              return ListTile(
                                title: Text(group),
                                selected: selected,
                                onTap: () => _setGroup(group),
                              );
                            },
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _buildAreaList(),
                        ),
                      ],
                    ),
            ),
            if (_errorMessage != null)
              Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirm(),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaList() {
    final activeGroup = _activeGroup;
    if (activeGroup == null) {
      return const SizedBox.shrink();
    }
    final entries = widget.groupedAreas[activeGroup] ?? [];
    if (entries.isEmpty) {
      return const Center(child: Text('선택 가능한 지역이 없습니다.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final selected = _selectedIds.contains(entry.area.areaId);
        return ListTile(
          title: Text(entry.childLabel),
          subtitle: entry.childLabel == entry.area.name
              ? null
              : Text(entry.area.name),
          trailing: selected
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          selected: selected,
          onTap: () => _toggleArea(entry.area.areaId),
        );
      },
    );
  }
}

class _GroupedAreaData {
  _GroupedAreaData(this.grouped, this.byId);

  final Map<String, List<_AreaListEntry>> grouped;
  final Map<int, _AreaListEntry> byId;
}

class _AreaListEntry {
  _AreaListEntry({
    required this.area,
    required this.childLabel,
  });

  final AreaOption area;
  final String childLabel;
}
