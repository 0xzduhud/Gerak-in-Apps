import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'chat_message.dart';
import 'chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  /// Membuka layar chat dengan ChatProvider miliknya sendiri.
  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider<ChatProvider>(
        create: (_) => ChatProvider()..init(),
        child: const ChatScreen(),
      ),
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _suggestions = [
    'Rekomendasi latihan 15 menit untuk pemula',
    'Cara pemanasan yang benar sebelum olahraga',
    'Tips menjaga konsistensi olahraga',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(String text) {
    final chat = context.read<ChatProvider>();
    if (chat.isSending) return;
    chat.sendMessage(text);
    _controller.clear();
  }

  Future<void> _confirmClear(ChatProvider chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus riwayat chat?'),
        content: const Text(
          'Seluruh percakapan di perangkat ini akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await chat.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;

    Widget content;
    if (chat.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (messages.isEmpty && !chat.isSending) {
      content = _EmptyState(suggestions: _suggestions, onPick: _send);
    } else {
      final offset = chat.isSending ? 1 : 0;
      content = ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        itemCount: messages.length + offset,
        itemBuilder: (context, index) {
          if (chat.isSending && index == 0) {
            return const _TypingBubble();
          }
          final message = messages[messages.length - 1 - (index - offset)];
          return _MessageBubble(message: message);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fitness Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Hapus riwayat',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: messages.isEmpty || chat.isSending
                ? null
                : () => _confirmClear(chat),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: content),
            if (!chat.historyAvailable)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'Riwayat chat tidak tersimpan di perangkat ini.',
                  style: TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
            if (chat.errorMessage != null)
              _ErrorBar(
                message: chat.errorMessage!,
                onDismiss: chat.dismissError,
                onRetry: chat.canRetry ? chat.retryLast : null,
              ),
            _buildInputBar(chat),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ChatProvider chat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
              decoration: const InputDecoration(
                hintText: 'Tanya seputar olahraga...',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty && !chat.isSending;
              return IconButton.filled(
                tooltip: 'Kirim',
                onPressed: canSend ? () => _send(value.text) : null,
                icon: const Icon(Icons.send_rounded),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.suggestions, required this.onPick});

  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 52, color: cs.primary),
            const SizedBox(height: 16),
            const Text(
              'Fitness Assistant',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tanya seputar latihan, pemulihan, dan kebiasaan hidup sehat.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final text in suggestions)
                  ActionChip(label: Text(text), onPressed: () => onPick(text)),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Jawaban AI bisa keliru dan bukan pengganti saran tenaga medis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  /// Teks Gemini sering memakai tanda markdown. Dibersihkan agar enak dibaca
  /// sebagai teks biasa.
  static String _cleanReply(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^#{1,6}[ \t]*', multiLine: true), '')
        .replaceAll(RegExp(r'^[ \t]*[*-][ \t]+', multiLine: true), '• ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final failed = message.isError;

    final background = isUser
        ? (failed ? cs.error.withValues(alpha: 0.25) : cs.primary)
        : cs.surface;
    final foreground = isUser
        ? (failed ? cs.onSurface : cs.onPrimary)
        : cs.onSurface;

    final text = isUser ? message.content : _cleanReply(message.content);
    final time = DateFormat('HH:mm').format(message.createdAt);
    final maxWidth = MediaQuery.of(context).size.width * 0.8;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: failed
                      ? Border.all(color: cs.error.withValues(alpha: 0.6))
                      : null,
                ),
                child: SelectableText(
                  text,
                  style: TextStyle(color: foreground, height: 1.35),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (failed) ...[
                    Icon(
                      Icons.error_outline_rounded,
                      size: 12,
                      color: cs.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Gagal terkirim',
                      style: TextStyle(fontSize: 11, color: cs.error),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Mengetik...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({
    required this.message,
    required this.onDismiss,
    this.onRetry,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: cs.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Kirim ulang')),
          IconButton(
            tooltip: 'Tutup',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
