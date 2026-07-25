import 'package:flutter_test/flutter_test.dart';
import 'package:flightpath_mobile/services/compat_service.dart';

void main() {
  const requester = '11111111-1111-4111-8111-111111111111';
  const target = '22222222-2222-4222-8222-222222222222';

  test('request insert uses target_id from the frozen schema', () {
    expect(CompatService.requestInsert(requester, target), {
      'requester_id': requester,
      'target_id': target,
      'status': 'pending',
    });
  });

  test('self requests and malformed IDs are rejected', () {
    expect(() => CompatService.requestInsert(requester, requester),
        throwsFormatException);
    expect(() => CompatService.requestInsert(requester, 'not-an-id'),
        throwsFormatException);
  });
}
