import 'package:flutter/material.dart';

import 'block.dart';
import 'blockchain_service.dart';

class DetailBlockchainScreen extends StatefulWidget {
  const DetailBlockchainScreen({
    super.key,
    required this.userId,
    required this.blocks,
  });

  final String userId;
  final List<Block> blocks;

  @override
  State<DetailBlockchainScreen> createState() => _DetailBlockchainScreenState();
}

class _DetailBlockchainScreenState extends State<DetailBlockchainScreen> {
  late List<Block> _blocks;
  bool _isVerifying = false;
  bool? _isChainValid;
  String? _verificationError;

  @override
  void initState() {
    super.initState();
    _blocks = List<Block>.of(widget.blocks);
    _verifyChain();
  }

  Future<void> _verifyChain() async {
    setState(() {
      _isVerifying = true;
      _verificationError = null;
    });

    try {
      final service = BlockchainService();
      final valid = await service.verifyChain(widget.userId);
      final blocks = await service.getChain(widget.userId);

      if (!mounted) return;

      setState(() {
        _blocks = blocks;
        _isChainValid = valid;
        _isVerifying = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isChainValid = false;
        _verificationError = 'Verifikasi gagal: $error';
        _isVerifying = false;
      });
    }
  }

  String _formatTimestamp(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestampMs,
      isUtc: true,
    ).toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}:'
        '${twoDigits(date.second)}';
  }

  Future<void> _copyText(String label, String value) async {
    // Menggunakan SelectableText agar hash dapat dipilih dan disalin
    // melalui menu teks bawaan Flutter.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(child: SelectableText(value)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Blockchain',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Verifikasi ulang',
            onPressed: _isVerifying ? null : _verifyChain,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _verifyChain,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Status Blockchain',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isVerifying)
                      const LinearProgressIndicator()
                    else
                      Row(
                        children: [
                          Icon(
                            _isChainValid == true
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _isChainValid == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isChainValid == true
                                  ? 'Rantai valid'
                                  : 'Rantai belum valid',
                              style: TextStyle(
                                color: _isChainValid == true
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_verificationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _verificationError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text('Jumlah blok: ${_blocks.length}'),
                    const SizedBox(height: 4),
                    Text(
                      'Setiap blok memiliki hash yang diperiksa '
                      'dan terhubung ke blok sebelumnya.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Daftar Blok',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_blocks.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum ada blok yang tersimpan.'),
                ),
              )
            else
              ..._blocks.reversed.map((block) {
                final isGenesis =
                    block.achievementId == Block.genesisAchievementId;
                final hashValid =
                    block.isHashValid && block.hash.startsWith('00');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    initiallyExpanded: block.index == _blocks.last.index,
                    leading: CircleAvatar(
                      child: Icon(
                        isGenesis ? Icons.flag_rounded : Icons.link_rounded,
                      ),
                    ),
                    title: Text(
                      isGenesis
                          ? 'Block #${block.index} · Genesis'
                          : 'Block #${block.index}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isGenesis
                          ? 'Blok awal blockchain'
                          : 'Achievement: ${block.achievementId}',
                    ),
                    trailing: Icon(
                      hashValid
                          ? Icons.verified_rounded
                          : Icons.warning_rounded,
                      color: hashValid ? Colors.green : Colors.orange,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _DetailRow(
                        label: 'Indeks blok',
                        value: block.index.toString(),
                      ),
                      _DetailRow(label: 'User ID', value: block.userId),
                      _DetailRow(
                        label: 'Achievement ID',
                        value: block.achievementId,
                      ),
                      _DetailRow(
                        label: 'Waktu',
                        value: _formatTimestamp(block.timestampMs),
                      ),
                      _DetailRow(label: 'Nonce', value: block.nonce.toString()),
                      _DetailRow(
                        label: 'Hash valid',
                        value: hashValid ? 'Ya' : 'Tidak',
                      ),
                      _DetailRow(
                        label: 'Previous hash',
                        value: block.prevHash,
                        onTap: () => _copyText('Previous hash', block.prevHash),
                      ),
                      _DetailRow(
                        label: 'Hash blok',
                        value: block.hash,
                        onTap: () => _copyText('Hash blok', block.hash),
                      ),
                      _DetailRow(label: 'Data blok', value: block.data),
                      const SizedBox(height: 8),
                      Text(
                        'Ketuk hash untuk melihat teks lengkap, '
                        'lalu pilih dan salin teksnya.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(
                value,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}
