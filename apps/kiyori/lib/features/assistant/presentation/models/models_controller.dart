import 'package:flutter/foundation.dart';
import 'package:kiyori_bridge/kiyori_bridge.dart';
import 'package:kiyori_platform/kiyori_platform.dart';

import 'model_credentials.dart';

/// Rust配置事实的投影；安全值只在显式编辑期间读取。
class ModelsController extends ChangeNotifier {
  ModelsController(this.connect, this.openSecrets, {TextExchange? exchange})
    : exchange = exchange ?? createTextExchange();
  final TextExchange exchange;
  final Future<RuntimeClient> Function() connect;
  final Future<SecretStore> Function() openSecrets;
  ModelCatalog? catalog;
  bool loading = false, _disposed = false;
  String? error;
  String? cleanupWarning;
  int _generation = 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final generation = ++_generation;
    loading = true;
    error = null;
    _notify();
    try {
      final value = await (await connect()).modelCatalog();
      if (!_disposed && generation == _generation) catalog = value;
      try {
        final lease = await (await connect()).beginModelSecrets();
        try {
          await cleanupRetired(lease: lease);
        } finally {
          await lease.close();
        }
        cleanupWarning = null;
      } catch (_) {
        cleanupWarning = '旧安全凭据清理未完成，点击重试';
      }
    } catch (_) {
      if (!_disposed && generation == _generation) error = '模型配置读取失败，请重试';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<ModelCredentials> readCredentials(ModelConfig config) async {
    final runtime = await connect();
    final lease = await runtime.beginModelSecrets();
    try {
      final current = (await runtime.modelCatalog()).configs
          .where((item) => item.id == config.id)
          .firstOrNull;
      if (current == null ||
          current.revision != config.revision ||
          current.secretReference != config.secretReference) {
        throw const SecretStoreException('stale');
      }
      if (current.secretReference == null) return const ModelCredentials();
      final value = await (await openSecrets()).read(current.secretReference!);
      if (value == null) throw const SecretStoreException('missing');
      return ModelCredentials.decode(value);
    } finally {
      await lease.close();
    }
  }

  Future<void> cleanupRetired({ModelSecretsWrite? lease}) async {
    final runtime = await connect();
    final owned = lease ?? await runtime.beginModelSecrets();
    try {
      final references = await runtime.retiredModelSecrets();
      if (references.isEmpty) return;
      final secrets = await openSecrets();
      for (final reference in references) {
        // 读取短lease也使用同一锁；退役引用必须等在途native读取结束后再删。
        await secrets.delete(reference);
        await runtime.forgetRetiredModelSecret(reference);
      }
    } finally {
      if (lease == null) await owned.close();
    }
  }

  Future<ModelConfig> save(
    ModelConfig base,
    ModelConfigDraft draft,
    ModelCredentials before,
    ModelCredentials after, {
    String? replacement,
  }) async {
    final runtime = await connect();
    String? reserved;
    ModelSecretsWrite? lease;
    var reference = base.secretReference;
    final encoded = after.encode();
    try {
      if (encoded != before.encode()) {
        final secrets = await openSecrets();
        lease = await runtime.beginModelSecrets();
        reserved = await lease.reserve(base.id, base.revision);
        await secrets.writeNew(reserved, encoded);
        reference = reserved;
      }
      await runtime.saveModelConfig(
        base.id,
        base.revision,
        draft,
        reference,
        replacement,
      );
    } catch (_) {
      if (reserved != null) {
        try {
          // 活跃检查与退役在核心同一事务；提交响应丢失也不能删活跃凭据。
          await runtime.retireModelSecret(reserved);
          await cleanupRetired(lease: lease);
        } catch (_) {
          cleanupWarning = '部分安全凭据等待对账，原配置保持可恢复';
        }
      }
      rethrow;
    } finally {
      await lease?.close();
    }
    // 命令成功即事实。读目录失败也返回已提交revision，禁止误报失败再重复保存。
    final committed = ModelConfig(
      id: base.id,
      revision: base.revision + 1,
      draft: draft,
      secretReference: reference,
    );
    try {
      await cleanupRetired();
      cleanupWarning = null;
    } catch (_) {
      cleanupWarning = '配置已保存，旧安全凭据清理将在下次重试';
    }
    await load();
    return committed;
  }

  Future<String> create(String name) async {
    final id = await (await connect()).createModelConfig(name);
    await load();
    return id;
  }

  Future<void> delete(
    ModelConfig config, {
    String? replacementConfig,
    String? replacementModel,
  }) async {
    await (await connect()).deleteModelConfig(
      config.id,
      config.revision,
      replacementConfig,
      replacementModel,
    );
    try {
      await cleanupRetired();
    } catch (_) {
      cleanupWarning = '配置已删除，安全凭据清理将在下次重试';
    }
    await load();
  }

  Future<void> select(String function, String config, String model) async {
    await (await connect()).selectFunctionModel(function, config, model);
    await load();
  }

  Future<void> resetFunctions() async {
    await (await connect()).resetFunctionModels();
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
