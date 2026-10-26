// lib/features/favorites/presentation/edit_folder_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Importante
import '../../../models/folder_model.dart';
import '../../../providers/providers.dart';

class EditFolderDialog extends ConsumerStatefulWidget {
  final FolderModel folder;

  const EditFolderDialog({Key? key, required this.folder}) : super(key: key);

  @override
  ConsumerState<EditFolderDialog> createState() => _EditFolderDialogState();
}

class _EditFolderDialogState extends ConsumerState<EditFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  late String _selectedColor;
  late String _selectedIcon;

  // Usamos IDs en lugar de nombres fijos para poder traducirlos en el build
  final List<Map<String, dynamic>> _colors = [
    {'id': 'Blue', 'hex': '#2196F3'},
    {'id': 'Red', 'hex': '#F44336'},
    {'id': 'Green', 'hex': '#4CAF50'},
    {'id': 'Orange', 'hex': '#FF9800'},
    {'id': 'Purple', 'hex': '#9C27B0'},
    {'id': 'Pink', 'hex': '#E91E63'},
    {'id': 'Cyan', 'hex': '#00BCD4'},
    {'id': 'Yellow', 'hex': '#FFC107'},
  ];

  final List<Map<String, dynamic>> _icons = [
    {'id': 'Folder', 'icon': 'folder'},
    {'id': 'Beach', 'icon': 'beach'},
    {'id': 'Mountain', 'icon': 'mountain'},
    {'id': 'Favorite', 'icon': 'favorite'},
    {'id': 'Star', 'icon': 'star'},
    {'id': 'Trip', 'icon': 'trip'},
    {'id': 'Explore', 'icon': 'explore'},
    {'id': 'Map', 'icon': 'map'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder.name);
    _selectedColor = widget.folder.colorHex;
    _selectedIcon = widget.folder.iconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'beach': return Icons.beach_access;
      case 'mountain': return Icons.terrain;
      case 'favorite': return Icons.favorite;
      case 'star': return Icons.star;
      case 'trip': return Icons.flight;
      case 'explore': return Icons.explore;
      case 'map': return Icons.map;
      default: return Icons.folder;
    }
  }

  Future<void> _updateFolder() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    final folderService = ref.read(folderServiceProvider);

    final updatedFolder = widget.folder.copyWith(
      name: _nameController.text.trim(),
      colorHex: _selectedColor,
      iconName: _selectedIcon,
    );

    try {
      await folderService.updateFolder(updatedFolder);
      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.folderUpdatedSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.folderUpdateError}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Función auxiliar idéntica a la de CreateFolder para traducir etiquetas
    String translateId(String id) {
      switch (id) {
        case 'Blue': return l10n.colorBlue;
        case 'Red': return l10n.colorRed;
        case 'Green': return l10n.colorGreen;
        case 'Orange': return l10n.colorOrange;
        case 'Purple': return l10n.colorPurple;
        case 'Pink': return l10n.colorPink;
        case 'Cyan': return l10n.colorCyan;
        case 'Yellow': return l10n.colorYellow;
        case 'Folder': return l10n.iconFolder;
        case 'Beach': return l10n.iconBeach;
        case 'Mountain': return l10n.iconMountain;
        case 'Favorite': return l10n.iconFavorite;
        case 'Star': return l10n.iconStar;
        case 'Trip': return l10n.iconTrip;
        case 'Explore': return l10n.iconExplore;
        case 'Map': return l10n.iconMap;
        default: return id;
      }
    }

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.editFolderTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: l10n.folderNameLabel,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.edit),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.folderNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.colorLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((colorData) {
                    final isSelected = _selectedColor == colorData['hex'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = colorData['hex'];
                        });
                      },
                      child: Tooltip(
                        message: translateId(colorData['id']),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Color(int.parse(
                                colorData['hex'].replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.iconLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _icons.map((iconData) {
                    final isSelected = _selectedIcon == iconData['icon'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = iconData['icon'];
                        });
                      },
                      child: Tooltip(
                        message: translateId(iconData['id']),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(int.parse(
                                    _selectedColor.replaceFirst('#', '0xFF')))
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIconData(iconData['icon']),
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updateFolder,
                      child: Text(l10n.saveButton),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}