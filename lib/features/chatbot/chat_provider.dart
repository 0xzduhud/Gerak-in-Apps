import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/chat_local_db.dart';
import '../../core/services/chat_service.dart';
import 'chat_message.dart';

/// State percakapan chatbot. Dibuat per layar chat (lihat ChatScreen.route).
class ChatProvider extends ChangeNotifier {
  ChatProvider({ChatService? service, ChatLocalDb? localDb})
    : _service = service ?? ChatService(),
      _localDb = localDb ?? ChatLocalDb();

  /// Jumlah pesan terakhir yang dikirim sebagai konteks ke server.
  static const int _maxContextMessages = 10;

  final ChatService _service;
  final ChatLocalDb _localDb;

  final List<ChatMessage> _messages = [];

  String? _userId;
  bool _isLoading = true;
  bool _isSending = false;
  bool _historyAvailable = true;
  bool _disposed = false;
  String? _errorMessage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;

  /// False jika riwayat tidak bisa disimpan (misalnya di Chrome/web).
  bool get historyAvailable => _historyAvailable;

  String? get errorMessage => _errorMessage;

  /// True jika pesan terakhir adalah pesan pengguna yang gagal terkirim.
  bool get canRetry =>
      !_isSending &&
      _messages.isNotEmpty &&
      _messages.last.isUser &&
      _messages.last.isError;

  /// Memuat riwayat dari SQLite. Panggil sekali saat provider dibuat.
  Future<void> init() async {
    _userId = Supabase.instance.client.auth.currentUser?.id;

    if (_userId == null) {
      _errorMessage = 'Sesi login tidak ditemukan. Silakan login kembali.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final saved = await _localDb.getMessages(_userId!);
      _messages
        ..clear()
        ..addAll(saved);
    } catch (error) {
      // Tidak fatal: chat tetap jalan tanpa riwayat tersimpan.
      _historyAvailable = false;
      debugPrint('Riwayat chat tidak tersedia: $error');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Mengirim pesan baru dan menunggu balasan.
  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _isSending || _userId == null) return;

    _errorMessage = null;

    final userMessage = await _persist(
      ChatMessage(
        role: ChatRole.user,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    _messages.add(userMessage);
    notifyListeners();

    await _requestReply();
  }

  /// Mengirim ulang pesan pengguna terakhir yang gagal.
  Future<void> retryLast() async {
    if (!canRetry) return;

    final index = _messages.length - 1;
    final failed = _messages[index];
    _messages[index] = failed.copyWith(status: ChatStatus.sent);
    _errorMessage = null;
    notifyListeners();

    await _updateStatusSafely(failed.id, ChatStatus.sent);
    await _requestReply();
  }

  Future<void> clearHistory() async {
    if (_isSending || _userId == null) return;

    _messages.clear();
    _errorMessage = null;
    notifyListeners();

    try {
      await _localDb.clearHistory(_userId!);
    } catch (error) {
      debugPrint('Gagal menghapus riwayat: $error');
    }
  }

  void dismissError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _requestReply() async {
    _isSending = true;
    notifyListeners();

    try {
      // Pesan yang gagal tidak ikut dikirim sebagai konteks.
      final history = _messages
          .where((m) => !m.isError)
          .toList()
          .reversed
          .take(_maxContextMessages)
          .toList()
          .reversed
          .map((m) => m.toApi())
          .toList();

      final reply = await _service.sendMessage(history);

      final modelMessage = await _persist(
        ChatMessage(
          role: ChatRole.model,
          content: reply,
          createdAt: DateTime.now(),
        ),
      );
      _messages.add(modelMessage);
    } on ChatServiceException catch (error) {
      _errorMessage = error.message;
      await _markLastUserMessageFailed();
    } catch (error) {
      debugPrint('Kesalahan tak terduga di chat: $error');
      _errorMessage = 'Terjadi kesalahan. Coba lagi.';
      await _markLastUserMessageFailed();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> _markLastUserMessageFailed() async {
    if (_messages.isEmpty || !_messages.last.isUser) return;

    final index = _messages.length - 1;
    final failed = _messages[index];
    _messages[index] = failed.copyWith(status: ChatStatus.error);
    await _updateStatusSafely(failed.id, ChatStatus.error);
  }

  Future<ChatMessage> _persist(ChatMessage message) async {
    if (!_historyAvailable || _userId == null) return message;

    try {
      return await _localDb.insertMessage(_userId!, message);
    } catch (error) {
      _historyAvailable = false;
      debugPrint('Riwayat chat tidak bisa disimpan: $error');
      return message;
    }
  }

  Future<void> _updateStatusSafely(int? id, ChatStatus status) async {
    if (!_historyAvailable || id == null) return;
    try {
      await _localDb.updateStatus(id, status);
    } catch (error) {
      debugPrint('Gagal memperbarui status pesan: $error');
    }
  }

  // Layar bisa ditutup saat permintaan masih berjalan. Setelah dispose,
  // notifikasi diabaikan supaya tidak error.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
