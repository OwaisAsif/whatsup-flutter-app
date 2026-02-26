import 'package:agora_token_generator/agora_token_generator.dart';

String generateToken({
  required String appId,
  required String appCertificate,
  required String channelName,
  required int uid,
  int ttlSeconds = 3600,
}) {
  return RtcTokenBuilder.buildTokenWithUid(
    appId: appId,
    appCertificate: appCertificate,
    channelName: channelName,
    uid: uid,
    tokenExpireSeconds: ttlSeconds,
  );
}
