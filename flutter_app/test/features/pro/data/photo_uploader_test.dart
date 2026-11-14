import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lemqes/features/pro/data/media_storage.dart';
import 'package:lemqes/features/pro/data/photo_uploader.dart';
import 'package:lemqes/features/pro/data/pro_api.dart';
import 'package:lemqes/features/pro/data/pro_failure.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements ProApi {}

class _MockStorage extends Mock implements MediaStorage {}

void main() {
  late _MockApi api;
  late _MockStorage storage;
  late PhotoUploader uploader;
  final file = XFile.fromData(
    Uint8List.fromList([0xFF, 0xD8, 3]),
    name: 'a.jpg',
  );
  final shape = RegExp(r'^pro1/[0-9a-f-]{36}\.jpg$');

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    api = _MockApi();
    storage = _MockStorage();
    uploader = PhotoUploader(api, storage);
    when(() => storage.upload(any(), any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => storage.remove(any(), any())).thenAnswer((_) async {});
  });

  test(
    'work photo: object name <proId>/<uuid>.jpg, row path equals it',
    () async {
      when(() => api.insert('pro_photos', any())).thenAnswer(
        (i) async => {
          'id': 'ph1',
          'path': (i.positionalArguments[1] as Map)['path'],
          'sort': 0,
        },
      );
      final photo = await uploader.addWorkPhoto('pro1', file);
      final captured =
          verify(
                () => storage.upload('work-photos', captureAny(), any(), any()),
              ).captured.single
              as String;
      expect(captured, matches(shape));
      expect(photo.path, captured);
      final values =
          verify(() => api.insert('pro_photos', captureAny())).captured.single
              as Map<String, Object?>;
      expect(values['pro_id'], 'pro1');
      expect(values['path'], captured);
    },
  );

  test('work photo: object removed when the row insert fails', () async {
    when(() => api.insert('pro_photos', any()))
        .thenThrow(Exception('too_many_photos'));
    await expectLater(uploader.addWorkPhoto('pro1', file), throwsA(anything));
    final path =
        verify(() => storage.upload('work-photos', captureAny(), any(), any()))
                .captured
                .single
            as String;
    verify(() => storage.remove('work-photos', [path])).called(1);
  });

  test('content type and extension come from the bytes', () async {
    when(() => api.insert('pro_photos', any())).thenAnswer(
      (i) async => {
        'id': 'ph1',
        'path': (i.positionalArguments[1] as Map)['path'],
        'sort': 0,
      },
    );
    final png = XFile.fromData(
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]),
      name: 'x.jpg',
    );
    final webp = XFile.fromData(
      Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]),
      name: 'x.jpg',
    );
    final p1 = await uploader.addWorkPhoto('pro1', png);
    final p2 = await uploader.addWorkPhoto('pro1', webp);
    final p3 = await uploader.addWorkPhoto('pro1', file);
    expect(p1.path, matches(RegExp(r'^pro1/[0-9a-f-]{36}\.png$')));
    expect(p2.path, matches(RegExp(r'^pro1/[0-9a-f-]{36}\.webp$')));
    expect(p3.path, matches(shape));
    verify(() => storage.upload('work-photos', p1.path, any(), 'image/png'));
    verify(() => storage.upload('work-photos', p2.path, any(), 'image/webp'));
    verify(() => storage.upload('work-photos', p3.path, any(), 'image/jpeg'));
  });

  test(
    'unrecognised bytes (HEIC, text) are rejected before any upload',
    () async {
      final heic = XFile.fromData(
        Uint8List.fromList([
          0,
          0,
          0,
          0x18,
          0x66,
          0x74,
          0x79,
          0x70,
          0x68,
          0x65,
          0x69,
          0x63,
        ]),
        name: 'x.heic',
      );
      await expectLater(
        uploader.addWorkPhoto('pro1', heic),
        throwsA(isA<UnsupportedImage>()),
      );
      await expectLater(
        uploader.uploadAvatar('pro1', XFile.fromData(Uint8List(0))),
        throwsA(isA<UnsupportedImage>()),
      );
      verifyNever(() => storage.upload(any(), any(), any(), any()));
      verifyNever(() => api.insert(any(), any()));
    },
  );

  test('work photo: no row when the upload fails', () async {
    when(() => storage.upload(any(), any(), any(), any()))
        .thenThrow(Exception('x'));
    await expectLater(uploader.addWorkPhoto('pro1', file), throwsA(anything));
    verifyNever(() => api.insert(any(), any()));
  });

  test('avatar: uploads then points avatar_path at the object', () async {
    when(() => api.update('pro_profiles', 'pro1', any()))
        .thenAnswer((_) async => {'id': 'pro1'});
    final path = await uploader.uploadAvatar('pro1', file);
    expect(path, matches(shape));
    verify(() => storage.upload('avatars', path, any(), any())).called(1);
    verify(() => api.update('pro_profiles', 'pro1', {'avatar_path': path}))
        .called(1);
  });

  test('avatar: object removed when the profile update fails', () async {
    when(() => api.update('pro_profiles', 'pro1', any()))
        .thenThrow(Exception('x'));
    await expectLater(uploader.uploadAvatar('pro1', file), throwsA(anything));
    final path =
        verify(() => storage.upload('avatars', captureAny(), any(), any()))
                .captured
                .single
            as String;
    verify(() => storage.remove('avatars', [path])).called(1);
  });

  test('removeWorkPhoto deletes the row then the object', () async {
    when(() => api.delete(any(), any())).thenAnswer((_) async {});
    await uploader.removeWorkPhoto(
      const ProPhoto(id: 'ph1', path: 'pro1/x.jpg', sort: 0),
    );
    verifyInOrder([
      () => api.delete('pro_photos', 'ph1'),
      () => storage.remove('work-photos', ['pro1/x.jpg']),
    ]);
  });

  test('publicUrl delegates to storage', () {
    when(() => storage.publicUrl('avatars', 'p/a.jpg')).thenReturn('u');
    expect(uploader.publicUrl('avatars', 'p/a.jpg'), 'u');
  });

  group('replacing the avatar', () {
    // The buckets are public: a replaced photo left in place stays reachable
    // by anyone who kept its URL.
    test(
      'removes the previous object once the row points at the new one',
      () async {
        when(() => api.update('pro_profiles', 'pro1', any()))
            .thenAnswer((_) async => {});
        final path = await uploader.uploadAvatar(
          'pro1',
          file,
          previous: 'pro1/old.jpg',
        );
        verifyInOrder([
          () => storage.upload('avatars', path, any(), 'image/jpeg'),
          () => api.update('pro_profiles', 'pro1', {'avatar_path': path}),
          () => storage.remove('avatars', ['pro1/old.jpg']),
        ]);
      },
    );

    test('a failed removal is logged, never fails the upload', () async {
      when(() => api.update('pro_profiles', 'pro1', any()))
          .thenAnswer((_) async => {});
      when(() => storage.remove('avatars', ['pro1/old.jpg']))
          .thenThrow(Exception('offline'));
      final path = await uploader.uploadAvatar(
        'pro1',
        file,
        previous: 'pro1/old.jpg',
      );
      expect(path, matches(RegExp(r'^pro1/[A-Za-z0-9_-]+\.(jpg|png|webp)$')));
    });

    test('keeps the previous object when the row update fails', () async {
      when(() => api.update('pro_profiles', 'pro1', any()))
          .thenThrow(Exception('denied'));
      await expectLater(
        uploader.uploadAvatar('pro1', file, previous: 'pro1/old.jpg'),
        throwsA(anything),
      );
      verifyNever(() => storage.remove('avatars', ['pro1/old.jpg']));
    });

    test('a first avatar removes nothing', () async {
      when(() => api.update('pro_profiles', 'pro1', any()))
          .thenAnswer((_) async => {});
      await uploader.uploadAvatar('pro1', file);
      verifyNever(() => storage.remove(any(), any()));
    });
  });

  // The storage policies and row CHECKs accept exactly this shape
  // (20261115000240_pro_storage_paths.sql).
  test('every generated object name fits the database path rule', () async {
    when(() => api.update('pro_profiles', 'pro1', any()))
        .thenAnswer((_) async => {});
    for (final bytes in [
      [0xFF, 0xD8, 1],
      [0x89, 0x50, 0x4E, 0x47],
      [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
    ]) {
      final path = await uploader.uploadAvatar(
        'pro1',
        XFile.fromData(Uint8List.fromList(bytes)),
      );
      expect(path, matches(RegExp(r'^pro1/[A-Za-z0-9_-]+\.(jpg|png|webp)$')));
    }
  });
}
