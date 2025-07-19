
// lib/requirements_screen.dart

import 'package:flutter/material.dart';
import 'camera_settings.dart';

/// 요구사항 모델
class Requirement {
  final String id, title, description;
  final DateTime createdAt;
  Requirement({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });
}

/// 요구사항 입력 & 리스트 화면
class RequirementsScreen extends StatefulWidget {
  final void Function(CameraSettings) onSettingsReceived;
  const RequirementsScreen({Key? key, required this.onSettingsReceived})
      : super(key: key);

  @override
  State<RequirementsScreen> createState() => _RequirementsScreenState();
}

class _RequirementsScreenState extends State<RequirementsScreen> {
  final _reqs = <Requirement>[];
  final _tCtrl = TextEditingController();
  final _dCtrl = TextEditingController();
  bool _busy = false;


  void _addReq() {
    if (_tCtrl.text.isEmpty) return;
    setState(() {
      _reqs.add(Requirement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _tCtrl.text,
        description: _dCtrl.text,
        createdAt: DateTime.now(),
      ));
      _tCtrl.clear();
      _dCtrl.clear();
    });
    Navigator.pop(context);
  }

  Future<void> _runReq(Requirement r) async {
    setState(() => _busy = true);
    final s = await ApiService.getMockCameraSettings(
        '${r.title} ${r.description}');
    widget.onSettingsReceived(s!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카메라 설정 업데이트 완료'),
          backgroundColor: Colors.green,
        ),
      );
    }
    setState(() => _busy = false);
  }

  void _showDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('새 요구사항 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tCtrl,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dCtrl,
              decoration: const InputDecoration(labelText: '상세 설명'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(onPressed: _addReq, child: const Text('추가')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('요구사항 관리')),
      body: Stack(
        children: [
          _reqs.isEmpty
              ? const Center(child: Text('등록된 요구사항이 없습니다'))
              : ListView.builder(
            itemCount: _reqs.length,
            itemBuilder: (_, i) {
              final r = _reqs[i];
              return ListTile(
                title: Text(r.title),
                subtitle: Text(
                    '${r.description}\n등록일: ${r.createdAt.toLocal().toIso8601String().split("T").first}'),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.camera_enhance, color: Colors.green),
                  onPressed: () => _runReq(r),
                ),
              );
            },
          ),
          if (_busy)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
