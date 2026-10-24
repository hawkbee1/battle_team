import 'package:backend_status_repository/backend_status_repository.dart';
import 'package:battle_team/app/app.dart';
import 'package:battle_team/bootstrap.dart';

Future<void> main() async {
  await bootstrap(
    (apiClient) => App(
      backendStatusRepository: BackendStatusRepository(apiClient: apiClient),
    ),
  );
}
