import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'private_group_call_screen.dart';

/// 50 flower-themed private group rooms.
///
/// Men see all live rooms; women see active rooms they can host/join.
/// Mutually exclusive with chat (P3 priority).
class PrivateGroupsListScreen extends StatefulWidget {
  final bool isMale;
  const PrivateGroupsListScreen({super.key, required this.isMale});

  @override
  State<PrivateGroupsListScreen> createState() =>
      _PrivateGroupsListScreenState();
}

class _PrivateGroupsListScreenState extends State<PrivateGroupsListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  static const _flowers = [
    '🌹', '🌻', '🌷', '🌸', '🌺', '🌼', '💐', '🪷', '🌾', '🍀',
    '🌵', '🌴', '🌳', '🌲', '🌱', '🍂', '🍁', '🪻', '🪴', '🌿',
    '🥀', '🌽', '🍇', '🍓', '🍒', '🍑', '🍍', '🥥', '🥝', '🍉',
    '🍊', '🍋', '🍐', '🍎', '🍏', '🥭', '🍌', '🥑', '🌶️', '🫐',
    '🦋', '🐝', '🐞', '🪲', '🐌', '🦚', '🦜', '🐦', '🕊️', '🦢',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('private_groups')
          .select('*, host:current_host_id(id, full_name, photo_url)')
          .eq('is_active', true)
          .order('created_at');
      setState(() {
        _rooms = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _openRoom(Map<String, dynamic> room) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrivateGroupCallScreen(
        roomId: room['id'] as String,
        roomName: room['name'] as String? ?? 'Room',
        isHost: !widget.isMale &&
            room['current_host_id'] == _supabase.auth.currentUser?.id,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Private Groups')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                itemCount: 50,
                itemBuilder: (_, i) {
                  final room = i < _rooms.length ? _rooms[i] : null;
                  final flower = _flowers[i % _flowers.length];
                  final isLive = room != null;
                  return InkWell(
                    onTap: room == null ? null : () => _openRoom(room),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isLive
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLive ? Colors.redAccent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(flower, style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 6),
                          Text('Room ${i + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (isLive)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('● LIVE',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
