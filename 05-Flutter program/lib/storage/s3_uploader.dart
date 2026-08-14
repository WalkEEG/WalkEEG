import 'dart:typed_data';

import 'package:aws_client/s3_2006_03_01.dart';

import '../auth/cognito_auth.dart';
import '../config/app_config.dart';

class S3Uploader {
  Future<void> uploadBytes({
    required AwsCredentials credentials,
    required String key,
    required Uint8List bytes,
    String contentType = 'text/csv',
  }) async {
    final s3 = S3(
      region: AppConfig.region,
      credentials: AwsClientCredentials(
        accessKey: credentials.accessKeyId,
        secretKey: credentials.secretAccessKey,
        sessionToken: credentials.sessionToken,
      ),
    );

    await s3.putObject(
      bucket: AppConfig.dataBucket,
      key: key,
      body: bytes,
      contentType: contentType,
    );
  }
}
