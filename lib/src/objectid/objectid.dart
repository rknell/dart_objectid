import 'dart:typed_data';
import 'dart:math' as math;

import 'package:objectid/src/hash/murmurHash2.dart';
import 'package:objectid/src/process_unique/process_unique.dart';

/// ## ObjectId
/// This class allows you to create and manipulate bson ObjectIds.
///
/// Example:
/// ```dart
/// final id = ObjectId();
/// final id2 = ObjectId.fromHexString('5f527e9b350aa5f9709daf16');
/// final id3 = ObjectId.fromBytes([95, 82, 126, 187, 124, 177, 57, 83, 165, 119, 211, 48]);
/// final id4 = ObjectId.fromValues(timestamp, processUnique, counter);
/// ```
class ObjectId {
  static const _maxCounterValue = 0xffffff;
  static const _objectIdBytesLength = 12;
  static const _objectIdHexStringLength = _objectIdBytesLength * 2;

  /// 5 bytes of process and timestamp specific random number.
  static final int _processUnique = ProcessUnique().getValue();

  /// ObjectId counter that will be used for ObjectId generation.
  ///
  /// Initialized with random value.
  static int _counter = math.Random().nextInt(_maxCounterValue);

  /// Get ObjectId counter by incrementing current counter value by 1.
  /// ObjectId counter cannot be larger than 3 bits.
  static int _getCounter() => (_counter = (_counter + 1) % _maxCounterValue);

  final Uint8List _bytes = Uint8List(_objectIdBytesLength);

  /// ObjectId bytes.
  Uint8List get bytes => _bytes;

  DateTime _timestamp;

  /// Returns the generation date (accurate up to the second) that this ObjectId was generated.
  DateTime get timestamp {
    if (_timestamp != null) return _timestamp;

    var secondsSinceEpoch = 0;
    for (var x = 3, y = 0; x >= 0; x--, y++) {
      secondsSinceEpoch += _bytes[x] * math.pow(256, y);
    }

    return _timestamp =
        DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  }

  /// ### Creates ObjectId.
  ///
  /// {@template objectid.structure}
  /// #### ObjectId structure:
  /// ```
  ///   4 byte timestamp    5 byte process unique   3 byte counter
  /// |<----------------->|<---------------------->|<------------>|
  /// |----|----|----|----|----|----|----|----|----|----|----|----|
  /// 0                   4                   8                   12
  /// ```
  /// {@endtemplate}
  ///
  ObjectId() {
    _initialize(DateTime.now().millisecondsSinceEpoch, _processUnique,
        ObjectId._getCounter());
  }

  /// ### Creates ObjectId from provided values.
  ///
  /// {@macro objectid.structure}
  ObjectId.fromValues(
    int millisecondsSinceEpoch,
    int processUnique,
    int counter,
  ) {
    ArgumentError.checkNotNull(millisecondsSinceEpoch, 'timestamp');
    ArgumentError.checkNotNull(processUnique, 'processUnique');
    ArgumentError.checkNotNull(counter, 'counter');

    _initialize(millisecondsSinceEpoch, processUnique, counter);
  }

  /// ### Creates ObjectId from provided timestamp.
  /// Only timestamp segment is set while the rest of the ObjectId is zeroed out.
  ///
  /// Example:
  /// ```
  /// final id = ObjectId.fromTimestamp(DateTime.now());
  /// ```
  /// {@macro objectid.structure}
  ObjectId.fromTimestamp(DateTime timestamp) {
    ArgumentError.checkNotNull(timestamp, 'timestamp');

    final secondsSinceEpoch = timestamp.millisecondsSinceEpoch ~/ 1000;

    // 4-byte timestamp
    _bytes[3] = secondsSinceEpoch & 0xff;
    _bytes[2] = (secondsSinceEpoch >> 8) & 0xff;
    _bytes[1] = (secondsSinceEpoch >> 16) & 0xff;
    _bytes[0] = (secondsSinceEpoch >> 24) & 0xff;
  }

  /// ### Creates ObjectId from hex string.
  /// Can be helpful for mapping hext strings returned from
  /// API / mongodb to ObjectId instances.
  ///
  /// Example usage:
  /// ```dart
  /// final id = ObjectId();
  /// final id2 = ObjectId.fromHexString(id.hexString);
  /// print(id == id2) // => true
  /// ```
  /// {@macro objectid.structure}
  ObjectId.fromHexString(String hexString) {
    ArgumentError.checkNotNull(hexString, 'hexString');
    if (hexString.length != _objectIdHexStringLength) {
      throw ArgumentError.value(
          hexString, 'hexString', 'Provided hexString has wrong length.');
    }

    final secondsSinceEpoch = int.parse(hexString.substring(0, 8), radix: 16);
    final millisecondsSinceEpoch = secondsSinceEpoch * 1000;

    final processUnique = int.parse(hexString.substring(8, 18), radix: 16);
    final counter = int.parse(hexString.substring(18, 24), radix: 16);

    _initialize(millisecondsSinceEpoch, processUnique, counter);
  }

  /// Internally initialize ObjectId instance by filling
  /// bytes array with provided data.
  void _initialize(int millisecondsSinceEpoch, int processUnique, int counter) {
    final secondsSinceEpoch = millisecondsSinceEpoch ~/ 1000;

    // 4-byte timestamp
    _bytes[3] = secondsSinceEpoch & 0xff;
    _bytes[2] = (secondsSinceEpoch >> 8) & 0xff;
    _bytes[1] = (secondsSinceEpoch >> 16) & 0xff;
    _bytes[0] = (secondsSinceEpoch >> 24) & 0xff;

    // 5-byte process unique
    _bytes[8] = processUnique & 0xff;
    _bytes[7] = (processUnique >> 8) & 0xff;
    _bytes[6] = (processUnique >> 16) & 0xff;
    _bytes[5] = (processUnique >> 24) & 0xff;
    _bytes[4] = (processUnique >> 32) & 0xff;

    // 3-byte counter
    _bytes[11] = counter & 0xff;
    _bytes[10] = (counter >> 8) & 0xff;
    _bytes[9] = (counter >> 16) & 0xff;
  }

  /// ### Creates ObjectId from bytes.
  /// Example usage:
  /// ```dart
  /// final id = ObjectId();
  /// final id2 = ObjectId.fromBytes(id.bytes);
  /// print(id == id2) // => true
  /// ```
  ///
  /// {@macro objectid.structure}
  ObjectId.fromBytes(List<int> bytes) {
    ArgumentError.checkNotNull(bytes, 'bytes');
    if (bytes.length != _objectIdBytesLength) {
      throw ArgumentError.value(
        bytes,
        'bytes',
        'Bytes array should has length equal to $_objectIdBytesLength',
      );
    }

    for (var i = 0; i < _bytes.length; i++) {
      _bytes[i] = bytes[i];
    }
  }

  /// Whether hexString is a valid ObjectId
  static bool isValid(String hexString) {
    try {
      if (hexString?.length != 24) return false;

      int.parse(hexString.substring(0, 8), radix: 16);
      int.parse(hexString.substring(8, 18), radix: 16);
      int.parse(hexString.substring(18, 24), radix: 16);
    } catch (err) {
      return false;
    }
    return true;
  }

  String _hexString;

  /// Returns hex string for current [ObjectId].
  String get hexString {
    if (_hexString == null) {
      _hexString = '';
      for (var i = 0; i < _bytes.length; i++) {
        _hexString += _bytes[i].toRadixString(16).padLeft(2, '0');
      }
    }

    return _hexString;
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    for (var i = 0; i < _bytes.length; i++) {
      if ((other as ObjectId)._bytes[i] != _bytes[i]) return false;
    }
    return true;
  }

  /// Caches [hashCode].
  /// Prevents multiple calculations of the same value.
  int _hashCode;
  @override
  int get hashCode => _hashCode ??= murmurHash2(bytes, runtimeType.hashCode);

  @override
  String toString() => '$runtimeType($hexString)';
}