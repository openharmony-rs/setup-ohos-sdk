# OHOS SDK

This is a simple GitHub action to automatically download and install the OpenHarmony SDK,
so you can use it in your GitHub actions workflow.

## Usage

```yaml
name: Main

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Setup OpenHarmony SDK
        uses: openharmony-rs/setup-ohos-sdk@v0.2
```

### Options

**inputs**:

| Name       | Type    | Default | Description                                                                           |
|------------|---------|---------|---------------------------------------------------------------------------------------|
| version    | String  | 5.0.0   | Version of the OpenHarmony SDK (e.g. `4.0`, `4.1`, `5.0.0` or `5.0.1`)                |
| cache      | Boolean | true    | Uses the GitHub actions cache to cache the SDK when enabled.                          |
| components | String  | all     | SDK components that should be added. `all` or semicolon seperated list of components. |
| mirror     | Boolean | true    | Download from Github Releases mirror of the SDK if possible.                          |

**outputs**:


| Name            | Type   | Description                                                                             |
|-----------------|--------|-----------------------------------------------------------------------------------------|
| api-version     | String | API Version of the SDK (e.g. `12` for OpenHarmony 5.0.0, or `13` for OpenHarmony 5.0.1) |
| sdk-version     | String | Specific SDK version (e.g. `4.1.7.5`)                                                   |
| ohos_sdk_native | String | Path to the `native` directory in the OpenHarmony SDK.                                  |


### Supported SDK versions

This action supports installing the following SDK versions: 

- `4.0` (API 10)
- `4.1` (API 11)
- `5.0.0` (API 12)
- `5.0.1` (API 13)
- `5.0.2` (API 14)
- `5.0.3` (API 15)
- `5.1.0` (API 18)
