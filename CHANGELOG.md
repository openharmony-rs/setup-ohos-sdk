# v0.1.4 (2024-10-08)

- Fixed a bug introduced in v0.1.3, which caused the action to not set output variables,
  when a cache hit occurred.
- Fixed an issue with version `5.0` not downloading from the github releases mirror, when
  the mirror option is enabled.

# v0.1.3 (2024-10-07)

- Now supports installing the OpenHarmony 5.0 SDK.
- The `components` input now defaults to `all`, since `hvigor` 5 will throw an error if not all
  components are installed.
