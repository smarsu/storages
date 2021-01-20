# storage

磁盘存储的封装, 使得人们能够更加安全地将文件缓存到磁盘中, 并且不会担心无限制地占用磁盘空间.

使用`FixSizedStorage`而非随意地存储缓存文件, 你会获得:

- 不在担心无限制地占用磁盘空间
- 不用担心操作系统删除缓存数据
- 性能极佳, 基本等同于`Map`的key to value访问

## 参数
| 参数名   | 类型    | 描述              | 默认值 |
| ---      | ---    | ---               | ---   |
| id       | String | storage的唯一标示  | 无    |
| capacity | int    | storage的存储上限  | 5GB   |

## 使用
- 如何使用`FixSizedStorage`
```dart
fixSizedStorage = FixSizedStorage('example', capacity: 1024);  // 利用[id]和[capacity]初始化FixSizedStorage
await fixSizedStorage.init();  // 每次初始化后需要执行[init]

String keyStr = '$key';  // 将[key]转化为str从而可以当作fixSizedStorage的key
String value = await fixSizedStorage.get(keyStr);  // 通过[key]尝试获取缓存的[value]
if (value == null) {  // 如果[key]不在缓存中的话, 此时[value]为null, 并且需要尝试将新的[key]-[value]插入到storage中
  String path = await fixSizedStorage.touch(keyStr);  // 获取缓存数据的路径
  await File(path).writeAsBytes(bytes);  // do something you want
  bool set = await fixSizedStorage.set(keyStr, path);  // 尝试将[key]-[value]插入在storage中, 成功返回true, 否则返回false.
  value = path;
}
```

## 注意
每次创建`FixSizedStorage`实例后需要调用`init()`将缓存在磁盘中的数据捞到内存中

传给`FixSizedStorage`的`key`应该能够作为一个有效的文件名

在执行完`FixSizedStorage`的`set`方法后不应该再对缓存文件(即`path`对应的文件)做写操作了; 如果做了写操作, 需要再次执行`FixSizedStorage`的`set`方法来调整文件size

如果`FixSizedStorage`的`set`方法返回为false, 那么说明`key`和`value`插入`FixSizedStorage`失败了, 此时`path`对应的文件也会被删除

## TODO
* [ ] 如果用户在do something时程序闪退或者操作系统导致此时存储的文件有所损坏, 如何识别出该损坏的文件
* [ ] 优化`_deleteFirstDeactiveKeyValue`函数, 减少delete or set key-value的次数
