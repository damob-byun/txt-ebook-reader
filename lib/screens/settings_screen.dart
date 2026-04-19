import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_settings_provider.dart';
import 'webdav_login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('장치 및 입력'),
          _buildSwitchTile(
            title: '볼륨 버튼으로 페이지 넘기기',
            subtitle: '모바일 기기의 볼륨 키를 사용하여 이전/다음 페이지 이동',
            value: settings.useVolumeKeys,
            onChanged: notifier.updateVolumeKeys,
          ),
          _buildSwitchTile(
            title: '화면 터치로 페이지 넘기기',
            subtitle: '화면 양쪽 가장자리를 터치하여 페이지 이동',
            value: settings.useTouchTurn,
            onChanged: notifier.updateTouchTurn,
          ),
          
          _buildSectionHeader('보기 모드'),
          _buildSwitchTile(
            title: '세로 연속 스크롤 모드',
            subtitle: '페이지 구분 없이 아래로 계속 읽기',
            value: settings.useScrollMode,
            onChanged: notifier.updateScrollMode,
          ),

          _buildSectionHeader('계정 관리'),
          ListTile(
            title: const Text('WebDAV 계정 설정'),
            subtitle: const Text('서버 주소 및 자격증명 수정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WebDavLoginScreen()),
              );
            },
          ),
          
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'MoonViewer v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B4E3D),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF6B4E3D),
    );
  }
}
