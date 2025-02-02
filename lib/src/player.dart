// Copyright 2022 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import 'generated_bindings.dart';
import 'global.dart';
import 'media_info.dart';
import 'lib.dart';
import 'extensions.dart';

class Player {

  int get nativeHandle => _player.address;

  Player() {
    _pp.value = _player;
    _fi.attach(this, this);
    Libfvp.registerPort(nativeHandle, NativeApi.postCObject.cast(), _receivePort.sendPort.nativePort);
    _receivePort.listen((message) {
      final type = message[0] as int;
      final rep = calloc<_CallbackReply>();
      switch (type) {
        case 0: { // event
          final error = message[1] as int;
          final category = message[2] as String;
          final detail = message[3] as String;
          final ev = MediaEvent(error, category, detail);
          if (_eventCb != null) {
            _eventCb!(ev);
          }
        }
        case 1: { // state
          final oldValue = message[1] as int;
          final newValue = message[2] as int;
          if (_stateCb != null) {
            _stateCb!(State.from(oldValue), State.from(newValue));
          }
          Libfvp.replyType(nativeHandle, type, nullptr);
        }
        case 2: { // media status
          final oldValue = message[1] as int;
          final newValue = message[2] as int;
          bool ret = true;
          if (_statusCb != null) {
            ret = _statusCb!(MediaStatus(oldValue), MediaStatus(newValue));
          }
          rep.ref.mediaStatus.ret = ret;
          Libfvp.replyType(nativeHandle, type, rep.cast());
        }
      }
      calloc.free(rep);
    });
  }

  void dispose() {
    if (_pp == nullptr) {
      return;
    }
    state = State.stopped;
    onEvent(null);
    onStateChanged(null);
    onMediaStatusChanged(null);

    Libfvp.unregisterPort(nativeHandle);

    _receivePort.close();

    Libmdk.instance.mdkPlayerAPI_delete(_pp);
    calloc.free(_pp);
    _pp = nullptr;
  }

  set mute(bool value) {
    _mute = value;
    _player.ref.setMute.asFunction<void Function(Pointer<mdkPlayer>, bool)>(isLeaf: true)(_player.ref.object, value);
  }

  bool get mute => _mute;

  set volume(double value) {
    _volume = value;
    _player.ref.setVolume.asFunction<void Function(Pointer<mdkPlayer>, double)>()(_player.ref.object, value);
  }

  double get volume => _volume;

  set media(String value) {
    _media = value;
    final cs = value.toNativeUtf8();
    _player.ref.setMedia.asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>)>()(_player.ref.object, cs.cast());
    malloc.free(cs);
  }

  String get media => _media;

  set audioDecoders(List<String> value) => setDecoders(MediaType.audio, value);

  List<String> get audioDecoders => _adec;

  set videoDecoders(List<String> value) => setDecoders(MediaType.video, value);

  List<String> get videoDecoders => _vdec;

  set activeAudioTracks(List<int> value) => setActiveTracks(MediaType.audio, value);
  List<int> get activeAudioTracks => _activeAT;

  set activeVideoTracks(List<int> value) => setActiveTracks(MediaType.video, value);
  List<int> get activeVideoTracks => _activeVT;

  set activeSubtitleTracks(List<int> value) => setActiveTracks(MediaType.subtitle, value);
  List<int> get activeSubtitleTracks => _activeST;

  set state(State value) {
    _state = value;
    _player.ref.setState.asFunction<void Function(Pointer<mdkPlayer>, int)>()(_player.ref.object, value.rawValue);
  }

  State get state => _state;

  MediaStatus get mediaStatus => MediaStatus(_player.ref.mediaStatus.asFunction<int Function(Pointer<mdkPlayer>)>()(_player.ref.object));

  set loop(int value) {
    _loop = value;
    _player.ref.setLoop.asFunction<void Function(Pointer<mdkPlayer>, int)>()(_player.ref.object, value);
  }

  int get loop => _loop;

  set preloadImmediately(bool value) {
    _preloadImmediately = value;
    _player.ref.setPreloadImmediately.asFunction<void Function(Pointer<mdkPlayer>, bool)>()(_player.ref.object, value);
  }

  bool get preloadImmediately => _preloadImmediately;

  int get position => _player.ref.position.asFunction<int Function(Pointer<mdkPlayer>)>()(_player.ref.object);

  set playbackRate(double value) {
    _playbackRate = value;
    _player.ref.setPlaybackRate.asFunction<void Function(Pointer<mdkPlayer>, double)>()(_player.ref.object, value);
  }

  double get playbackRate => _playbackRate;

  MediaInfo get mediaInfo {
    _mediaInfoC = _player.ref.mediaInfo.asFunction<Pointer<mdkMediaInfo> Function(Pointer<mdkPlayer>)>()(_player.ref.object);
    return MediaInfo.from(_mediaInfoC);
  }

  void prepare({int position = 0, SeekFlag flags = const SeekFlag(SeekFlag.defaultFlags)}) {
    final cb = calloc<mdkPrepareCallback>();
    //cb.ref.cb =
    _player.ref.prepare.asFunction<void Function(Pointer<mdkPlayer>, int, mdkPrepareCallback, int)>()(_player.ref.object, position, cb.ref, flags.rawValue);
    calloc.free(cb);
  }

  void setDecoders(MediaType type, List<String> value) {
    switch (type) {
    case MediaType.audio:
      _adec = value;
    case MediaType.video:
      _vdec = value;
    default:
    }

    final u8p = value.toCZ();
    _player.ref.setDecoders.asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Pointer<Char>>)>()(_player.ref.object, type.rawValue, u8p.cast());
    u8p.free();
  }

  void setActiveTracks(MediaType type, List<int> value) {
    switch (type) {
    case MediaType.audio:
      _activeAT = value;
    case MediaType.video:
      _activeVT = value;
    case MediaType.subtitle:
      _activeST = value;
    default:
    }
    final ca = calloc<Int>(value.length);
    for (int i = 0; i < value.length; ++i) {
      ca[i] = value[i];
    }
    _player.ref.setActiveTracks.asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Int>, int)>()(_player.ref.object, type.rawValue, ca.cast(), value.length);
    calloc.free(ca);
  }

  void setMedia(String uri, MediaType type) {
    final cs = uri.toNativeUtf8();
    _player.ref.setMediaForType.asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>, int)>()(_player.ref.object, cs.cast(), type.rawValue);
    malloc.free(cs);
  }

  void setNext(String uri, {int from = 0, SeekFlag seekFlag = const SeekFlag(SeekFlag.defaultFlags)}) {
    final cs = uri.toNativeUtf8();
    _player.ref.setNextMedia.asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>, int, int)>()(_player.ref.object, cs.cast(), from, seekFlag.rawValue);
    malloc.free(cs);
  }

  bool waitFor(State state, {int timeout = -1}) => _player.ref.waitFor.asFunction<bool Function(Pointer<mdkPlayer>, int, int)>()(_player.ref.object, state.rawValue, timeout);

  bool seek({required int position, SeekFlag flags = const SeekFlag(SeekFlag.defaultFlags), void Function(int)? callback}) {
    final cb = calloc<mdkSeekCallback>();
    //cb.ref.cb =
    // FIXME: seek flags seems not work
    final ret =_player.ref.seekWithFlags.asFunction<bool Function(Pointer<mdkPlayer>, int, int, mdkSeekCallback)>()(_player.ref.object, position, flags.rawValue, cb.ref);
    calloc.free(cb);
    return ret;
  }

  int buffered() {
    //var cbytes = calloc<Int64>();
    final ret =_player.ref.buffered.asFunction<int Function(Pointer<mdkPlayer>, Pointer<Int64>)>()(_player.ref.object, nullptr);
    //cbytes.value
    //calloc.free(cbytes);
    return ret;
  }

  void setBufferRange({int min = -1, int max = -1, bool drop = false}) => _player.ref.setBufferRange.asFunction<void Function(Pointer<mdkPlayer>, int, int, bool)>()(_player.ref.object, min, max, drop);

  void switchBitrate(String url, {int delay = -1, void Function(bool)? callback}) {
    // TODO:
  }

  void record({String? to, String? format}) {
    final cto = to?.toNativeUtf8();
    final cfmt = format?.toNativeUtf8();
    _player.ref.record.asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>, Pointer<Char>)>()(_player.ref.object, cto?.cast() ?? nullptr, cfmt?.cast() ?? nullptr);
    if (cto != null) {
      malloc.free(cto);
    }
    if (cfmt != null) {
      malloc.free(cfmt);
    }
  }

  void setRange({required int from, int to = -1}) => _player.ref.setRange.asFunction<void Function(Pointer<mdkPlayer>, int, int)>()(_player.ref.object, from, to);

  void setProperty(String name, String value) {
    final ck = name.toNativeUtf8();
    final cv = value.toNativeUtf8();
    _player.ref.setProperty.asFunction<void Function(Pointer<mdkPlayer>, Pointer<Char>, Pointer<Char>)>()(_player.ref.object, ck.cast(), cv.cast());
    malloc.free(ck);
    malloc.free(cv);
  }

  String? getProperty(String name) {
    final ck = name.toNativeUtf8();
    final cv = _player.ref.getProperty.asFunction<Pointer<Char> Function(Pointer<mdkPlayer>, Pointer<Char>)>()(_player.ref.object, ck.cast());
    malloc.free(ck);
    if (cv.address == 0) {
      return null;
    }
    return cv.cast<Utf8>().toDartString();
  }

  // video renderer apis
  void setVideoSurfaceSize(int width, int height, {Object? vid}) => _player.ref.setVideoSurfaceSize.asFunction<void Function(Pointer<mdkPlayer>, int, int, Pointer<Void>)>()(_player.ref.object, width, height, Pointer.fromAddress(vid.hashCode));

  void setVideoViewport(double x, double y, double width, double height, {Object? vid}) => _player.ref.setVideoViewport.asFunction<void Function(Pointer<mdkPlayer>, double, double, double, double, Pointer<Void>)>()(_player.ref.object, x, y, width, height, Pointer.fromAddress(vid.hashCode));

// value can be: ignoreAspectRatio, keepAspectRatio, keepAspectRatioCrop and other actual ratio value(width/height)
  void setAspectRatio(double value, {Object? vid}) => _player.ref.setAspectRatio.asFunction<void Function(Pointer<mdkPlayer>, double, Pointer<Void>)>()(_player.ref.object, value, Pointer.fromAddress(vid.hashCode));

  // TODO: mapPoint( List<double>)

  void rotate(int degree, {Object? vid}) => _player.ref.rotate.asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Void>)>()(_player.ref.object, degree, Pointer.fromAddress(vid.hashCode));

  void scale(double x, double y, {Object? vid}) => _player.ref.scale.asFunction<void Function(Pointer<mdkPlayer>, double, double, Pointer<Void>)>()(_player.ref.object, x, y, Pointer.fromAddress(vid.hashCode));

  void setBackgroundColor(double r, double g, double b, double a, {Object? vid}) => _player.ref.setBackgroundColor.asFunction<void Function(Pointer<mdkPlayer>, double, double, double, double, Pointer<Void>)>()(_player.ref.object, r, g, b, a, Pointer.fromAddress(vid.hashCode));

  void setBackground(Color c, {Object? vid}) => _player.ref.setBackgroundColor.asFunction<void Function(Pointer<mdkPlayer>, double, double, double, double, Pointer<Void>)>()(_player.ref.object, c.red/255, c.green/255, c.blue/255, c.alpha/255, Pointer.fromAddress(vid.hashCode));

  void setVideoEffect(VideoEffect effect, List<double> value, {Object? vid}) {
    final cv = calloc<Float>(value.length);
    for (int i = 0; i < value.length; ++i) {
      cv[i] = value[i];
    }
    _player.ref.setVideoEffect.asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Float>, Pointer<Void>)>()(_player.ref.object, effect.rawValue, cv.cast(), Pointer.fromAddress(vid.hashCode));
    calloc.free(cv);
  }

  void setColorSpace(ColorSpace value, {Object? vid}) => _player.ref.setColorSpace.asFunction<void Function(Pointer<mdkPlayer>, int, Pointer<Void>)>()(_player.ref.object, value.rawValue, Pointer.fromAddress(vid.hashCode));

  double renderVideo({Object? vid}) => _player.ref.renderVideo.asFunction<double Function(Pointer<mdkPlayer>, Pointer<Void>)>()(_player.ref.object, Pointer.fromAddress(vid.hashCode));

  // callbacks
  void onEvent(void Function(MediaEvent)? callback) {
    _eventCb = callback;
    if (callback == null) {
      Libfvp.unregisterType(nativeHandle, 0);
    } else {
      Libfvp.registerType(nativeHandle, 0, false);
    }
  }

// reply: true to let native code wait for dart callback result
  void onStateChanged(void Function(State oldValue, State newValue)? callback, {bool reply = false}) {
    _stateCb = callback;
    if (callback == null) {
      Libfvp.unregisterType(nativeHandle, 1);
    } else {
      Libfvp.registerType(nativeHandle, 1, reply);
    }
  }

// reply: true to let native code wait for dart callback result, may result in dead lock because when native waiting main isolate reply, main isolate may execute another task(e.g. frequent seekTo) which also acquire the same lock in native
// TODO: can add multiple callbacks, the last 1 reply parameter works
  void onMediaStatusChanged(bool Function(MediaStatus oldValue, MediaStatus newValue)? callback, {bool reply = false}) {
    _statusCb = callback;
    if (callback == null) {
      Libfvp.unregisterType(nativeHandle, 2);
    } else {
      Libfvp.registerType(nativeHandle, 2, reply);
    }
  }

  final _player = Libmdk.instance.mdkPlayerAPI_new();
  var _pp = calloc<Pointer<mdkPlayerAPI>>();

  static final _fi = Finalizer((p0) {
    final p = p0 as Player;
    p.dispose();
  });



  final _receivePort = ReceivePort();

  void Function(MediaEvent)? _eventCb;
  void Function(State oldValue, State newValue)? _stateCb;
  bool Function(MediaStatus oldValue, MediaStatus newValue)? _statusCb;

  bool _mute = false;
  double _volume = 1.0;
  String _media = "";
  List<String> _adec = ["auto"];
  List<String> _vdec = ["auto"];
  List<int> _activeAT = [0];
  List<int> _activeVT = [0];
  List<int> _activeST = [0];
  State _state = State.stopped;
  int _loop = 0;
  bool _preloadImmediately = true;
  double _playbackRate = 1.0;
  Pointer<mdkMediaInfo> _mediaInfoC = nullptr; // MediaInfo has views on mdkMediaInfo
}


final class _CallbackReply extends Union {
  external UnnamedStruct5 mediaStatus;
  external UnnamedStruct6 sync1;
  external UnnamedStruct7 prepared;
}

final class UnnamedStruct5 extends Struct {
  @Bool()
  external bool ret;
}

final class UnnamedStruct6 extends Struct {
  @Double()
  external double ret;
}

final class UnnamedStruct7 extends Struct {
  @Bool()
  external bool ret;
  @Bool()
  external bool boost;
}
