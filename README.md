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
        uses: openharmony-rs/setup-ohos-sdk@v0.1
```

### Options

**inputs**:

| Name       | Type    | Default | Description                                                                                                                |
|------------|---------|---------|----------------------------------------------------------------------------------------------------------------------------|
| version    | String  | 4.1     | Version of the OpenHarmony SDK (e.g. `4.0`, `4.1` or `5.0`)                                                                |
| cache      | Boolean | true    | Uses the GitHub actions cache to cache the SDK when enabled.                                                               |
| components | String  | all     | SDK components that should be added. `all` or semicolon seperated list of components.                                      |
| mirror     | Boolean | true    | Download from Github Releases mirror of the SDK if possible.                                                               |

**outputs**:


| Name            | Type   | Description                                            |
|-----------------|--------|--------------------------------------------------------|
| api-version     | String | API Version of the SDK (e.g. `12` for OpenHarmony 5.0) |
| sdk-version     | String | Specific SDK version (e.g. `4.1.7.5`)                  |
| ohos_sdk_native | String | Path to the `native` directory in the OpenHarmony SDK. |
