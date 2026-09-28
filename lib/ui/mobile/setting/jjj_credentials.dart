/*
 * Copyright 2026 Lolikongaaa. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/components/jjj_token_interceptor.dart';
import 'package:proxypin/ui/mobile/setting/ssl.dart';

/// [JJJ] 皎皎角凭据展示页（M2 v0）
///
/// 读取拦截器落盘的 jjj_token.json，分字段展示 token / devCode /
/// refreshToken 并支持一键复制，供魔改版 DNAUID 的 StringConfig
/// 分字段粘贴使用；未抓到凭据时给出证书 + 抓包引导。
///
/// @author Lolikongaaa 2026/09/28
class JjjCredentialsPage extends StatefulWidget {
  final ProxyServer proxyServer;

  const JjjCredentialsPage({super.key, required this.proxyServer});

  @override
  State<StatefulWidget> createState() {
    return _JjjCredentialsState();
  }
}

class _JjjCredentialsState extends State<JjjCredentialsPage> {
  JjjCredential? credential;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var cred = await JjjTokenInterceptor.readStoredCredential();
    if (mounted) {
      setState(() {
        credential = cred;
        loading = false;
      });
    }
  }

  void _copy(String label, String value) {
    if (value.isEmpty) {
      FlutterToastr.show('$label 为空', context);
      return;
    }
    Clipboard.setData(ClipboardData(text: value));
    FlutterToastr.show('$label 已复制', context);
  }

  bool get _hasData => credential != null && !credential!.isEmpty;

  String get _updatedText {
    var ms = credential?.updatedAt ?? 0;
    if (ms <= 0) {
      return '';
    }
    var dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '更新于 ${dt.month}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('皎皎角凭据'), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _statusCard(),
                const SizedBox(height: 12),
                if (_hasData) ...[
                  _fieldCard('Token', credential!.token),
                  _fieldCard('devCode', credential!.devCode),
                  _fieldCard('refreshToken', credential!.refreshToken),
                ] else
                  _guideCard(),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() => loading = true);
                    _load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _statusCard() {
    return Card(
      child: ListTile(
        leading: Icon(
          _hasData ? Icons.verified : Icons.info_outline,
          color: _hasData ? Colors.green : Colors.orange,
        ),
        title: Text(_hasData ? '凭据已抓取' : '尚未抓到凭据'),
        subtitle: Text(
          _hasData ? _updatedText : '启动抓包后打开官方 App 即可自动提取',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _fieldCard(String label, String value) {
    var controller = TextEditingController(text: value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                TextButton.icon(
                  onPressed: () => _copy(label, value),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('复制', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            TextField(
              controller: controller,
              readOnly: true,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _guideCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('获取凭据步骤',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            const Text('1. 安装并信任 HTTPS 证书（点击下方入口）'),
            const Text('2. 回主页启动抓包（VPN 连接）'),
            const Text('3. 打开皎皎角官方 App 登录或刷新数据'),
            const Text('4. 回到本页点「刷新」查看凭据'),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security),
              title: const Text('打开 HTTPS 证书设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MobileSslWidget(proxyServer: widget.proxyServer)));
              },
            ),
            Text(
              '注意：官方 App 重新登录后 token 会变化，以本页最新抓到的为准。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
