import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_exception.dart';
import '../../core/providers.dart';
import '../../models/patient.dart';
import '../../models/session.dart';
import '../auth/session_controller.dart';

final ownOverviewProvider = FutureProvider.autoDispose<PatientOverview>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is! SessionAuthenticated ||
      session.session.principal.role != 'patient') {
    throw const UnauthorizedException();
  }
  return ref
      .watch(apiProvider)
      .getPatientOverview(session.session.principal.patientId!);
});
