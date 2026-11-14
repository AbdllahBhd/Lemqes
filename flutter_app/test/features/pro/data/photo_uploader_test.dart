import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lemqes/features/pro/data/media_storage.dart';
import 'package:lemqes/features/pro/data/photo_uploader.dart';
import 'package:lemqes/features/pro/data/pro_api.dart';
import 'package:lemqes/features/pro/data/pro_models.dart';
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements ProApi {}

class _MockStorage extends Mock implements MediaStorage {}

void main() {
  late _MockApi api;
  late _MockStorage storage;
  late PhotoUploader uploader;
  final file = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.jpg');
  final shape = RegExp(r'^pro1/[0-9a-f-]{36}\.jpg$');

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() {
    api = _MockApi();
    storage = _MockStorage();
    uploader = PhotoUploader(api, storage);
    when(() => storage.upload(any(), any(), any())).thenAnswer((_) async {});
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
          verify(() => storage.upload('work-photos', captureAny(), any()))
                  .captured
                  .single
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
        verify(() => storage.upload('work-photos', captureAny(), any()))
                .captured
                .single
            as String;
    verify(() => storage.remove('work-photos', [path])).called(1);
  });

  test('work photo: no row when the upload fails', () async {
    when(() => storage.upload(any(), any(), any())).thenThrow(Exception('x'));
    await expectLater(uploader.addWorkPhoto('pro1', file), throwsA(anything));
    verifyNever(() => api.insert(any(), any()));
  });

  test('avatar: uploads then points avatar_path at the object', () async {
    when(() => api.update('pro_profiles', 'pro1', any()))
        .thenAnswer((_) async => {'id': 'pro1'});
    final path = await uploader.uploadAvatar('pro1', file);
    expect(path, matches(shape));
    verify(() => storage.upload('avatars', path, any())).called(1);
    verify(() => api.update('pro_profiles', 'pro1', {'avatar_path': path}))
        .called(1);
  });

  test('avatar: object removed when the profile update fails', () async {
    when(() => api.update('pro_profiles', 'pro1', any()))
        .thenThrow(Exception('x'));
    await expectLater(uploader.uploadAvatar('pro1', file), throwsA(anything));
    final path =
        verify(() => storage.upload('avatars', captureAny(), any()))
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
}
