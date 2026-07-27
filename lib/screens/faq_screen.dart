import 'package:flutter/material.dart';

import '../data/faq.dart';

const _bg = Color(0xFFF3F8F7);
const _teal = Color(0xFF0F766E);

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(title: const Text('Pusat Bantuan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.quiz_rounded, color: _teal, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pertanyaan yang sering diajukan seputar penggunaan aplikasi.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final section in faqSections) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                section.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE9EBEF)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < section.items.length; i++)
                    _FaqTile(
                      item: section.items[i],
                      showDivider: i != section.items.length - 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqItem item;
  final bool showDivider;

  const _FaqTile({required this.item, required this.showDivider});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[500],
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.item.answer,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: Colors.grey[700],
              ),
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOut,
        ),
        if (widget.showDivider)
          const Divider(height: 1, color: Color(0xFFE9EBEF)),
      ],
    );
  }
}
