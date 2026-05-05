import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/webdav_account.dart';
import '../providers/webdav_account_provider.dart';
import 'webdav_browser_screen.dart';

class WebDavLoginScreen extends ConsumerStatefulWidget {
  const WebDavLoginScreen({super.key});

  @override
  ConsumerState<WebDavLoginScreen> createState() => _WebDavLoginScreenState();
}

class _WebDavLoginScreenState extends ConsumerState<WebDavLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _useHttps = true;

  @override
  void initState() {
    super.initState();
    final account = ref.read(webDavAccountProvider);
    _hostController = TextEditingController(text: account?.host ?? '');
    _portController = TextEditingController(text: account?.port.toString() ?? '5006');
    _userController = TextEditingController(text: account?.username ?? '');
    _passController = TextEditingController(text: account?.password ?? '');
    _useHttps = account?.useHttps ?? true;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _saveAndConnect() async {
    if (_formKey.currentState!.validate()) {
      final account = WebDavAccount(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 443,
        username: _userController.text.trim(),
        password: _passController.text,
        useHttps: _useHttps,
      );

      await ref.read(webDavAccountProvider.notifier).saveAccount(account);
      
      if (!mounted) return;
      
      // Navigate to browser
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WebDavBrowserScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('WebDAV 설정', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '서버 정보를 입력하세요',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: isDark ? Colors.brown[200] : const Color(0xFF6B4E3D)
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _hostController,
                label: '서버 주소 (Host)',
                hint: 'example.com 또는 IP 주소',
                icon: Icons.dns_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _portController,
                      label: '포트 (Port)',
                      keyboardType: TextInputType.number,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: SwitchListTile(
                      title: Text('HTTPS 사용', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                      value: _useHttps,
                      onChanged: (v) => setState(() => _useHttps = v),
                      activeColor: const Color(0xFF6B4E3D),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _userController,
                label: '사용자 아이디 (User)',
                icon: Icons.person_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passController,
                label: '비밀번호 (Password)',
                obscureText: true,
                icon: Icons.lock_outline,
                isDark: isDark,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _saveAndConnect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4E3D),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('저장 및 연결하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.brown[200] : const Color(0xFF6B4E3D)) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark ? const BorderSide(color: Colors.white12) : const BorderSide(),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: isDark ? const BorderSide(color: Colors.white10) : const BorderSide(color: Colors.black12),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
      validator: (v) => v == null || v.isEmpty ? '필수 입력 항목입니다.' : null,
    );
  }
}
