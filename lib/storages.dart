import 'dart:collection';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// An implementation of FixSizedStorage.
/// 
/// FixSizedStorage ensures that the space you cache files to the directory 
/// will not grow indefinitely.
/// 
/// The space limit is limited by [capacity].
/// 
/// It may delete the cached data when the space is insufficient.
class FixSizedStorage {
  /// Create a FixSizedStorage instance with [id] and [capacity].
  /// 
  /// [id] is the unique identifier of the storage.
  /// 
  /// By default, the [capacity] is 5G.
  FixSizedStorage(String id, {int capacity = 5 * 1024 * 1024 * 1024}) {
    this._id = id;
    this._capacity = capacity;
  }

  /// Exposed initialization interface.
  ///
  /// You can call it frequently, but in fact it will only be executed once.
  Future<void> init() async {
    if (_initialize == null) {
      _initialize = _init();
    }
    return _initialize;
  }

  /// Internal initialization interface.
  ///
  /// Create [root] dir if not exist and restore deactive map.
  Future<void> _init() async {
    String root = await _root();
    if (!await Directory(root).exists()) {
      await Directory(root).create(recursive: true);
    }

    await _restore();
  }

  /// Get a new file path or root.
  /// 
  /// The path is always valid. Just use it.
  /// 
  /// The path is consist of [$AppDir/__storage__/$_id/$suffix]
  /// 
  /// You should call touch like this: `touch(key)` to make sure it is safe to
  /// restore path to key.
  Future<String> touch(String suffix) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    String path = '$dir/__storage__/$_id/$suffix';
    return path;
  }

  /// Reture the value of key or [null].
  /// 
  /// It is just the same with `Map[]`.
  /// 
  /// When the key is not in [_activeCache] and [_deactiveCache], it will 
  /// reture [null].
  /// 
  /// If [key] in [_deactiveCache], the [key] will be actived to [_activeCache].
  Future<String> get(String key) async {
    String value = _activeCache[key];
    if (value == null) {
      if (_deactiveCache.containsKey(key)) {
        value = _deactiveCache[key];
        _deactiveCache.remove(key);
        _activeCache[key] = value;
      }
    }
    return value;
  }

  /// Associates the [key] with the given [value].
  /// 
  /// Before you call set, you should make sure that the [key] is not in cache 
  /// or the [value] of [key] have changed.
  /// 
  /// It will try to add a new kv to the active cache. If the storage limit is
  /// exceeded, the addition will fail and the corresponding file in the [value]
  /// will be deleted; otherwise, it will try to add kv to the cache. If the
  /// storage limit of activecache is exceeded and the total storage limit is
  /// not exceeded, the kv in deactivecache will be deleted and store the new kv.
  Future<bool> set(String key, String value) async {
    int size = await _valueToSize(value);

    if (await _isSafeToAddKeyValue(key, value, size)) {
      _addKeyValueToActive(key, value, size);
      return true;
    }
    else {
      await _safeDelete(value);
      return false;
    }
  }

  /// Restore cache from disk to memory.
  ///
  /// Load the kv cached in the disk to the memory. Where [key] is the file name
  /// and [value] is the file path.
  Future<void> _restore() async {
    String root = await _root();
    for (var fileSystemEntity in Directory(root).listSync(recursive: true)) {
      String key = _pathToKey(fileSystemEntity.path);
      String value = fileSystemEntity.path;
      int size = await _valueToSize(value);

      _addKeyValueToDeactive(key, value, size);
    }
  }

  /// Get the file size of [value].
  /// 
  /// It no such file, return 0.
  /// 
  /// It will be used to check the fixed size.
  Future<int> _valueToSize(String value) async {
    File fb = File(value);
    if (! await fb.exists()) {
      return 0;
    }
    else {
      return await fb.length();
    }
  }

  /// Get [key] from [path].
  ///
  /// The file name of the [path] is the [key].
  String _pathToKey(String path) {
    return path.split('/').last;
  }

  /// Add kv to [_activeCache].
  ///
  /// The corresponde size will be increased.
  void _addKeyValueToActive(String key, String value, int size) {
    _activeCache[key] = value;
    _keyToSize[key] = size;
    _size += size;
  }

  /// Add kv to [_deactiveCache].
  ///
  /// The corresponde size will be increased.
  void _addKeyValueToDeactive(String key, String value, int size) {
    _deactiveCache[key] = value;
    _keyToSize[key] = size;
    _size += size;
  }

  /// Check if there is enough space to store the kv.
  ///
  /// If the size is not enough, delete the kv in _deactiveCache firstly.
  Future<bool> _isSafeToAddKeyValue(String key, String value, int size) async {
    if (size + _size <= _capacity) {
      return true;
    }
    else if (_deactiveCache.length > 0) {
      await _deleteFirstDeactiveKeyValue();
      return await _isSafeToAddKeyValue(key, value, size);
    }
    else {
      return false;
    }
  }

  /// Delete the deactive kv if no space.
  ///
  /// Todo: Every time you delete, you should delete the last kv in 
  /// chronological order to reduce the number of sets. 
  /// There is still room for optimization.
  Future<void> _deleteFirstDeactiveKeyValue() async {
    String key = _deactiveCache.keys.first;
    String value = _deactiveCache[key];
    int size = _keyToSize[key];

    _deactiveCache.remove(key);
    _keyToSize.remove(key);
    _size -= size;

    await _safeDelete(value);
  }

  /// Safely delete file.
  ///
  /// If the file exists, delete the file.
  Future<void> _safeDelete(String value) async {
    File fb = File(value);
    if (await fb.exists()) {
      await fb.delete();
    }
  }

  /// The root directory of this storage.
  ///
  /// Every path generated by [touch] is under this [_root].
  Future<String> _root() async => await touch('');

  /// Internal initialization variable.
  ///
  /// It is set to make sure that the [_init] will only be called once.
  Future<void> _initialize;

  /// The id of storage.
  /// 
  /// This is the identifier of storage.
  String _id;

  /// The active cache of key values.
  ///
  /// It will trigger remove when touch the edge.
  HashMap<String, String> _activeCache = HashMap<String, String>();

  /// The deactive cache of key values.
  ///
  /// The deactive means is have been stored int the last time, 
  /// and key-value in it will be remove firstly.
  /// 
  /// Use [HashMap] to avoid worst case.
  HashMap<String, String> _deactiveCache = HashMap<String, String>();

  /// The HashMap of key to priority.
  ///
  /// Keep size for fixed storage.
  HashMap<String, int> _keyToSize = HashMap<String, int>();

  /// The total size of stored files.
  /// 
  /// It should be limited to fixed size.
  int _size = 0;

  /// The capacity of this storage.
  /// 
  /// The total size of this storage cannot larger than [_capacity].
  int _capacity = 0;
}
