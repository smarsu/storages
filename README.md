# storage

A wrapper of disk storage allows people to cache files to disk more securely without worrying about taking up disk space unlimitedly.

Using `FixSizedStorage` instead of storing cached files roughly, you get:

- No longer worry about taking up disk space unlimited
- No longer worry about the operating system deleting cached data
- Excellent performance, basically equivalent to key to value access of `Map`

## Parameters
| parameter name | dtype    | description              | defaults |
| ---            | ---      | ---                      | ---      |
| id       | String | unique identification of storage | -        |
| capacity | int    | storage limit                    | 5GB      |

## Usage
- How to use `FixSizedStorage`
```dart
fixSizedStorage = FixSizedStorage('example', capacity: 1024);  // Initialize FixSizedStorage with [id] and [capacity]
await fixSizedStorage.init();  // Need to execute [init] after each initialization

String keyStr = '$key';  // Convert [key] to String so that it can be used as the key of fixSizedStorage
String value = await fixSizedStorage.get(keyStr);  // Try to get the cached [value] through [key]
if (value == null) {  // If [key] is not in the cache, [value] is null at this time, and you need to try to insert a new [key]-[value] into the storage
  String path = await fixSizedStorage.touch(keyStr);  // Path to get cached data
  await File(path).writeAsBytes(bytes);  // do something you want
  bool set = await fixSizedStorage.set(keyStr, path);  // Try to insert [key]-[value] into storage, return true if successful, otherwise return false
  value = path;
}
```

## NOTE
Each time you create an instance of `FixSizedStorage`, you need to call `init()` to fish the data cached in the disk into the memory

The `key` passed to `FixSizedStorage` should be able to be a valid file name

After executing the `set` method of `FixSizedStorage`, you should no longer write to the cache file (that is, the file corresponding to `path`); if you do a write operation, you need to execute the `set` method of `FixSizedStorage` again to adjust file size

If the `set` method of `FixSizedStorage` returns false, then it means the insertion of `key` and `value` into `FixSizedStorage` failed, and the file corresponding to `path` will also be deleted

## TODO
* [ ] If the program crashes when the user `does something` or the operating system causes the file stored at this time to be damaged, how to identify the damaged file
* [ ] Optimize the `_deleteFirstDeactiveKeyValue` function to reduce the times of delete or set key-value
