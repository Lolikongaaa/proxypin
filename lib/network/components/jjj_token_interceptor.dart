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

import 'dart:convert';
import 'dart:io';

import 'package:proxypin/network/components/interceptor.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/file_read.dart';
import 'package:proxypin/network/util/logger.dart';

/// [JJJ] 皎皎角凭据模型
class JjjCredential {
  String token = '';
  String refreshToken = '';
  String devCode = '';
  int updatedAt = 0;

  bool get isEmpty => token.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refreshToken': refreshToken,
      'devCode': devCode,
      'updatedAt': updatedAt,
    };
  }

  static JjjCredential fromJson(Map<String, dynamic> json) {
    return JjjCredential()
      ..token = json['token'] ?? ''
      ..refreshToken = json['refreshToken'] ?? ''
      ..devCode = json['devCode'] ?? ''
      ..updatedAt = json['updatedAt'] ?? 0;
  }
}

/// [JJJ] 皎皎角 token 提取拦截器
///
/// 纯旁观：不修改、不拦截任何请求与响应，只从白名单域名（皎皎角 API）的
/// 请求头提取 token / devCode，从响应体提取 refreshToken，落盘供 UI 展示。
/// 上游 HostFilter 过滤后的请求才会进入拦截器，天然只处理皎皎角域名。
///
/// @author Lolikongaaa 2026/09/28
class JjjTokenInterceptor extends Interceptor {
  static final JjjTokenInterceptor instance = JjjTokenInterceptor._();

  /// 皎皎角 API 域名
  static const List<String> jjjHosts = [
    'dnabbs-api.yingxiong.com',
    'dna-api.yingxiong.com',
  ];

  JjjCredential _latest = JjjCredential();

  /// 最新的凭据快照
  JjjCredential get latest => _latest;

  JjjTokenInterceptor._() {
    _load();
  }

  bool _isJjjHost(String? host) {
    if (host == null) {
      return false;
    }
    return jjjHosts.any((h) => host == h || host.endsWith('.$h'));
  }

  /// 递归查找 refreshToken 字段
  String? _findRefreshToken(dynamic node) {
    if (node is Map) {
      for (var entry in node.entries) {
        if (entry.key == 'refreshToken' &&
            entry.value is String &&
            (entry.value as String).isNotEmpty) {
          return entry.value as String;
        }
        var found = _findRefreshToken(entry.value);
        if (found != null) {
          return found;
        }
      }
    } else if (node is List) {
      for (var item in node) {
        var found = _findRefreshToken(item);
        if (found != null) {
          return found;
        }
      }
    }
    return null;
  }

  @override
  Future<HttpRequest?> onRequest(HttpRequest request) async {
    try {
      if (!_isJjjHost(request.hostAndPort?.host)) {
        return request;
      }
      var changed = false;
      var token = request.headers.get('token');
      if (token != null && token.isNotEmpty && token != _latest.token) {
        _latest.token = token;
        changed = true;
        logger.i('[JJJ] token captured (${token.length} chars)');
      }
      var devCode = request.headers.get('devCode');
      if (devCode != null && devCode.isNotEmpty && devCode != _latest.devCode) {
        _latest.devCode = devCode;
        changed = true;
      }
      if (changed) {
        _latest.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _save();
      }
    } catch (e, stackTrace) {
      logger.e('[JJJ] extract credential from request failed', error: e, stackTrace: stackTrace);
    }
    return request;
  }

  @override
  Future<HttpResponse?> onResponse(HttpRequest request, HttpResponse response) async {
    try {
      if (!_isJjjHost(request.hostAndPort?.host)) {
        return response;
      }
      if (response.status.code != 200) {
        return response;
      }
      var body = response.bodyAsString;
      if (!body.contains('refreshToken')) {
        return response;
      }
      var refreshToken = _findRefreshToken(jsonDecode(body));
      if (refreshToken != null && refreshToken != _latest.refreshToken) {
        _latest.refreshToken = refreshToken;
        _latest.updatedAt = DateTime.now().millisecondsSinceEpoch;
        await _save();
        logger.i('[JJJ] refreshToken captured');
      }
    } catch (e, stackTrace) {
      logger.e('[JJJ] extract refreshToken from response failed', error: e, stackTrace: stackTrace);
    }
    return response;
  }

  /// 凭据存储文件（与配置文件同目录）
  static Future<File> storeFile() async {
    var configFile = await FileRead.homeDir();
    return File("${configFile.parent.path}${Platform.pathSeparator}jjj_token.json");
  }

  /// 读取已落盘的凭据（跨进程安全，供 UI 层使用）
  static Future<JjjCredential> readStoredCredential() async {
    try {
      var file = await storeFile();
      if (!await file.exists()) {
        return JjjCredential();
      }
      var content = await file.readAsString();
      if (content.isEmpty) {
        return JjjCredential();
      }
      return JjjCredential.fromJson(jsonDecode(content));
    } catch (e) {
      logger.e('[JJJ] read credential failed', error: e);
      return JjjCredential();
    }
  }

  Future<void> _save() async {
    try {
      var file = await storeFile();
      if (!await file.exists()) {
        file = await file.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_latest.toJson()));
    } catch (e) {
      logger.e('[JJJ] save credential failed', error: e);
    }
  }

  Future<void> _load() async {
    _latest = await readStoredCredential();
  }
}
