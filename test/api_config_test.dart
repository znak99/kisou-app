import 'package:flutter_test/flutter_test.dart';
import 'package:kisou_app/config/api_config.dart';

void main() {
  test('development accepts absolute HTTP and HTTPS API URLs', () {
    expect(
      resolveApiBaseUrl(
        environment: 'development',
        developmentBaseUrl: 'http://10.0.2.2:8000',
        productionBaseUrl: '',
        releaseMode: false,
      ),
      'http://10.0.2.2:8000',
    );
    expect(
      resolveApiBaseUrl(
        environment: 'development',
        developmentBaseUrl: 'https://dev.example.com/api',
        productionBaseUrl: '',
        releaseMode: false,
      ),
      'https://dev.example.com/api',
    );
  });

  test('production accepts only a safe absolute HTTPS API URL', () {
    expect(
      resolveApiBaseUrl(
        environment: 'production',
        developmentBaseUrl: '',
        productionBaseUrl: 'https://kisou.znak99.cloud',
        releaseMode: true,
      ),
      'https://kisou.znak99.cloud',
    );
  });

  test('release rejects development environment', () {
    expect(
      () => resolveApiBaseUrl(
        environment: 'development',
        developmentBaseUrl: 'http://127.0.0.1:8000',
        productionBaseUrl: '',
        releaseMode: true,
      ),
      throwsStateError,
    );
  });

  test('unknown environment is rejected', () {
    expect(
      () => resolveApiBaseUrl(
        environment: 'staging',
        developmentBaseUrl: 'https://dev.example.com',
        productionBaseUrl: 'https://example.com',
        releaseMode: false,
      ),
      throwsStateError,
    );
  });

  for (final invalidUrl in [
    '',
    'http://kisou.znak99.cloud',
    'https://',
    'https://user:password@kisou.znak99.cloud',
    'https://kisou.znak99.cloud?debug=true',
    'https://kisou.znak99.cloud#fragment',
    ' https://kisou.znak99.cloud',
  ]) {
    test('production rejects invalid API URL: "$invalidUrl"', () {
      expect(
        () => resolveApiBaseUrl(
          environment: 'production',
          developmentBaseUrl: '',
          productionBaseUrl: invalidUrl,
          releaseMode: true,
        ),
        throwsStateError,
      );
    });
  }

  test('Android flavor must match the selected environment', () {
    expect(
      () => validateAppFlavor(
        environment: 'development',
        flavor: 'prod',
        flavorRequired: true,
      ),
      throwsStateError,
    );
    expect(
      () => validateAppFlavor(
        environment: 'production',
        flavor: 'dev',
        flavorRequired: true,
      ),
      throwsStateError,
    );
    expect(
      () => validateAppFlavor(
        environment: 'production',
        flavor: null,
        flavorRequired: true,
      ),
      throwsStateError,
    );
    expect(
      () => validateAppFlavor(
        environment: 'development',
        flavor: 'dev',
        flavorRequired: true,
      ),
      returnsNormally,
    );
    expect(
      () => validateAppFlavor(
        environment: 'production',
        flavor: 'prod',
        flavorRequired: true,
      ),
      returnsNormally,
    );
  });

  test('platforms without configured native flavors allow no flavor', () {
    expect(
      () => validateAppFlavor(
        environment: 'production',
        flavor: null,
        flavorRequired: false,
      ),
      returnsNormally,
    );
  });
}
