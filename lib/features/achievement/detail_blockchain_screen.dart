import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
          'Ethereum Sepolia Explorer',
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.token_rounded, color: Colors.blueAccent, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ethereum Sepolia Testnet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Chain ID: 11155111 · PoS Validated',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_isVerifying)
                      const LinearProgressIndicator()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (_isChainValid == true ? Colors.green : Colors.orange)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (_isChainValid == true ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isChainValid == true
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: _isChainValid == true
                                  ? Colors.green
                                  : Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isChainValid == true
                                    ? 'Konsensus & Rantai Blok Terverifikasi Valid'
                                    : 'Menunggu Verifikasi Jaringan Sepolia',
                                style: TextStyle(
                                  color: _isChainValid == true
                                      ? Colors.greenAccent
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_verificationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _verificationError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Total Blok Terverifikasi: ${_blocks.length} blok'),
                    const SizedBox(height: 4),
                    SelectableText(
                      'Smart Contract SBT: ${Block.sepoliaContractAddress}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontFamily: 'monospace',
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
                          ? 'Block #${block.index} · Sepolia Genesis'
                          : 'Block #${block.index} (Sepolia #${block.sepoliaBlockNumber})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isGenesis
                          ? 'Inisialisasi Ledger Sepolia Testnet'
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
                        label: 'Jaringan Blockchain',
                        value: Block.networkName,
                      ),
                      _DetailRow(
                        label: 'Nomor Blok Sepolia',
                        value: '#${block.sepoliaBlockNumber}',
                      ),
                      _DetailRow(
                        label: 'Indeks Blok',
                        value: block.index.toString(),
                      ),
                      _DetailRow(label: 'User ID', value: block.userId),
                      _DetailRow(
                        label: 'Achievement ID',
                        value: block.achievementId,
                      ),
                      _DetailRow(
                        label: 'Waktu Pencatatan',
                        value: _formatTimestamp(block.timestampMs),
                      ),
                      _DetailRow(
                        label: 'Transaction Hash (Sepolia)',
                        value: block.txHash,
                        onTap: () => _copyText('Transaction Hash', block.txHash),
                      ),
                      _DetailRow(
                        label: 'Previous Hash',
                        value: block.prevHash,
                        onTap: () => _copyText('Previous hash', block.prevHash),
                      ),
                      _DetailRow(
                        label: 'Smart Contract SBT',
                        value: Block.sepoliaContractAddress,
                        onTap: () => _copyText('Contract Address', Block.sepoliaContractAddress),
                      ),
                      _DetailRow(label: 'Nonce & Proof', value: block.nonce.toString()),
                      _DetailRow(label: 'Payload Data', value: block.data),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(block.etherscanUrl);
                            try {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Tidak dapat membuka browser.')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Buka di Sepolia Etherscan'),
                        ),
                      ),
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
