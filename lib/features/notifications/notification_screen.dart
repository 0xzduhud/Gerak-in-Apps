import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/timezone_converter.dart';
import '../../data/models/notification_model.dart';
import 'notification_provider.dart';

// [PBI-13.x] Pusat notifikasi dalam aplikasi.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationProvider>(
      create: (_) => NotificationProvider()..load(),
      child: const _NotificationView(),
    );
  }
}

class _NotificationView extends StatelessWidget {
  const _NotificationView();

  String _when(DateTime utc) {
    final t = utc.toLocal();
    return '${TimezoneConverter.formatDate(t)} • '
        '${TimezoneConverter.formatTime(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p.unreadCount > 0 ? 'Notifikasi (${p.unreadCount})' : 'Notifikasi',
        ),
        actions: [
          IconButton(
            tooltip: 'Kirim Notif Demo',
            icon: const Icon(Icons.notification_add_rounded, color: AppColors.primary),
            onPressed: () async {
              await p.sendDemoNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifikasi demo berhasil dikirim!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'demo') {
                await p.sendDemoNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifikasi demo berhasil dikirim!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
              if (v == 'read') p.markAllRead();
              if (v == 'clear') p.clearAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'demo', child: Text('Kirim Notif Demo')),
              PopupMenuItem(value: 'read', child: Text('Tandai semua dibaca')),
              PopupMenuItem(value: 'clear', child: Text('Hapus semua')),
            ],
          ),
        ],
      ),
      body: _body(context, p),
    );
  }

  Widget _body(BuildContext context, NotificationProvider p) {
    if (p.loading) return const Center(child: CircularProgressIndicator());
    if (p.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: p.load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (p.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Belum ada notifikasi.\nPengingat jadwal workout akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await p.sendDemoNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifikasi demo berhasil dikirim!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notification_add_rounded),
                label: const Text('Kirim Notifikasi Demo'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: p.load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: p.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final n = p.items[i];
          return Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.tertiary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            onDismissed: (_) => p.delete(n),
            child: Card(
              margin: EdgeInsets.zero,
              color: n.read ? AppColors.surface : AppColors.surfaceHigh,
              child: ListTile(
                onTap: () => p.markRead(n),
                leading: Icon(
                  n.kind == AppNotification.kindSchedule
                      ? Icons.alarm_rounded
                      : Icons.notifications_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text('${n.body}\n${_when(n.createdAt)}'),
                isThreeLine: true,
                trailing: n.read
                    ? null
                    : const Icon(Icons.circle,
                        size: 10, color: AppColors.secondary),
              ),
            ),
          );
        },
      ),
    );
  }
}
