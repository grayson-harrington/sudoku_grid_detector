import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// [ImageData] is a class that takes a ui.Image and allows the user
/// to access individual pixel color values from the image with the use of the
/// [pixelColorAt] method. Before pixel color values can be retrieved,
/// the [imageToByteData] function must be called to first obtain the image data
class ImageData {
  ui.Image _image;
  ByteData _byteData;
  int _width;
  int _height;

  ImageData({@required ui.Image image}) : this._image = image;

  int get width => _width;
  int get height => _height;
  Uint8List get rawBytes {
    return _Bitmap.fromHeadless(
      _width,
      _height,
      _byteData.buffer.asUint8List(),
    ).buildHeaded();
  }

  /// convert ui.Image to ByteData to be used in pixel getting
  /// this method must be called once after class initialization and before
  /// calling [pixelColorAt]
  Future<void> imageToByteData() async {
    if (_image == null) {
      print("image was null and couldn't get byteData");
      _byteData = null;
      _width = null;
      _height = null;
    } else {
      print("image wasn't null");
      _width = _image.width;
      print("image width: $_width");
      _height = _image.height;
      print("image height: $_height");
      _byteData = await _image.toByteData(format: ui.ImageByteFormat.rawRgba);
      print("byteData retrieved? ${_byteData == null ? "no" : "yes"}");
    }
  }

  /// Pixel coordinates: (0,0) → (width-1, height-1)
  Color getPixelColorAt(int x, int y) {
    if (_byteData == null ||
        _width == null ||
        _height == null ||
        x < 0 ||
        x >= _width ||
        y < 0 ||
        y >= _height)
      return null;
    else {
      var byteOffset = 4 * (x + (y * _width));
      return _colorAtByteOffset(byteOffset);
    }
  }

  /// Pixel coordinates: (0,0) → (width-1, height-1)
  void setPixelColorAt(int x, int y, Color c) {
    if (_byteData == null ||
        _width == null ||
        _height == null ||
        x < 0 ||
        x >= _width ||
        y < 0 ||
        y >= _height) {
      return;
    } else {
      var byteOffset = 4 * (x + (y * _width));
      _setColorAtByteOffset(byteOffset, c);
    }
  }

  void _setColorAtByteOffset(int byteOffset, Color c) {
    _byteData.setInt32(byteOffset, _colorToInt32(c));
  }

  int _colorToInt32(Color c) {
    return c.value;
  }

  Color _colorAtByteOffset(int byteOffset) {
    return Color(_rgbaToArgb(_byteData.getUint32(byteOffset)));
  }

  int _rgbaToArgb(int rgbaColor) {
    int a = rgbaColor & 0xFF;
    int rgb = rgbaColor >> 8;
    return rgb + (a << 24);
  }
}

/// https://github.com/renancaraujo/bitmap/blob/master/lib/bitmap.dart
/// my raw rgba data needs a header to be able to be instantiated as an image
/// this class from the above mentioned github link does that.
const int bitmapPixelLength = 4;
const int RGBA32HeaderSize = 122;
class _Bitmap {
  _Bitmap.fromHeadless(this.width, this.height, this.content);

  /*
  _Bitmap.fromHeadful(this.width, this.height, Uint8List headedIntList)
      : content = headedIntList.sublist(
    RGBA32HeaderSize,
    headedIntList.length,
  );
   */

  final int width;
  final int height;
  final Uint8List content;

  int get size => (width * height) * bitmapPixelLength;

  _Bitmap cloneHeadless() {
    return _Bitmap.fromHeadless(
      width,
      height,
      Uint8List.fromList(content),
    );
  }

  /*
  static Future<_Bitmap> fromProvider(ImageProvider provider) async {
    final Completer completer = Completer<ImageInfo>();
    final ImageStream stream = provider.resolve(const ImageConfiguration());
    final listener =
    ImageStreamListener((ImageInfo info, bool synchronousCall) {
      if (!completer.isCompleted) {
        completer.complete(info);
      }
    });
    stream.addListener(listener);
    final imageInfo = await completer.future;
    final ui.Image image = imageInfo.image;
    final ByteData byteData = await image.toByteData();
    final Uint8List listInt = byteData.buffer.asUint8List();

    return _Bitmap.fromHeadless(image.width, image.height, listInt);
  }
   */

  Future<ui.Image> buildImage() async {
    final Completer<ui.Image> imageCompleter = Completer();
    final headedContent = buildHeaded();
    ui.decodeImageFromList(headedContent, (ui.Image img) {
      imageCompleter.complete(img);
    });
    return imageCompleter.future;
  }

  Uint8List buildHeaded() {
    final header = _RGBA32BitmapHeader(size, width, height)
      ..applyContent(content);
    return header.headerIntList;
  }
}

class _RGBA32BitmapHeader {
  _RGBA32BitmapHeader(this.contentSize, int width, int height) {
    headerIntList = Uint8List(fileLength);

    final ByteData bd = headerIntList.buffer.asByteData();
    bd.setUint8(0x0, 0x42);
    bd.setUint8(0x1, 0x4d);
    bd.setInt32(0x2, fileLength, Endian.little);
    bd.setInt32(0xa, RGBA32HeaderSize, Endian.little);
    bd.setUint32(0xe, 108, Endian.little);
    bd.setUint32(0x12, width, Endian.little);
    bd.setUint32(0x16, -height, Endian.little);
    bd.setUint16(0x1a, 1, Endian.little);
    bd.setUint32(0x1c, 32, Endian.little); // pixel size
    bd.setUint32(0x1e, 3, Endian.little); //BI_BITFIELDS
    bd.setUint32(0x22, contentSize, Endian.little);
    bd.setUint32(0x36, 0x000000ff, Endian.little);
    bd.setUint32(0x3a, 0x0000ff00, Endian.little);
    bd.setUint32(0x3e, 0x00ff0000, Endian.little);
    bd.setUint32(0x42, 0xff000000, Endian.little);
  }

  int contentSize;

  void applyContent(Uint8List contentIntList) {
    headerIntList.setRange(
      RGBA32HeaderSize,
      fileLength,
      contentIntList,
    );
  }

  Uint8List headerIntList;

  int get fileLength => contentSize + RGBA32HeaderSize;
}
