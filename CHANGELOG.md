## [Unreleased]

## [0.2.4] - 2025-03-03

- Add configuration option for setting script CSP nonce (thanks @matthaigh27)

## [0.2.3] - 2025-02-28

- Add configuration API
- Make default prosopite ignore queries case insensitive

## [0.2.2] - 2025-02-27

- Increase default vernier allocation interval from 200 to 20k

## [0.2.1] - 2025-02-23

- Decrease default vernier allocation interval from 100k to 200
- Decrease default vernier interval from 500ms to 200ms

## [0.2.0] - 2025-02-22

- Perf: Eagerly check content type to avoid profiling incompatible requests
- Perf: Manually write vernier output files in background thread
- Use gzipped vernier output files by default
- UI: Use inline color properties to prevent overriding by user styles

## [0.1.9] - 2025-01-27

- Increase default vernier allocation interval from 10k to 100k

## [0.1.8] - 2025-01-27

- Require ruby 3.3.0 or later
- Handle stale file deletion in railtie, extend to log files
- Make log files unique to each session - simplify installation

## [0.1.7] - 2025-01-25

- Increase default vernier allocation interval from 1k to 10k

## [0.1.6] - 2025-01-25

- Fix redeclaration of JS constants

## [0.1.5] - 2025-01-24

- UI: Fix overflow and add vertical scroll

## [0.1.4] - 2024-12-27

- Use vernier memory usage and rails hooks by default
- Add support for N+1 detection with prosopite

## [0.1.3] - 2024-11-14

- Enable allocation profiling by default

## [0.1.2] - 2024-11-10

- Add support for request profiling with vernier

## [0.1.1] - 2024-11-08

- Initial release
