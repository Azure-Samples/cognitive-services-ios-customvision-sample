---
services: cognitive-services,custom-vision
platforms: Objective-C, iOS
author: kojiw
---

# Sample iOS application for CoreML models exported from Custom Vision Service

This sample application demonstrates how to take a model exported from the [Custom Vision Service](https://www.customvision.ai) in the CoreML format and add it to an application for real-time image classification. 

## Getting Started

### Prerequisites

- [XCode 10](https://developer.apple.com/xcode/)
- [CocoaPods](https://cocoapods.org)
- iOS device running iOS 11 or later
- An account at [Custom Vision Service](https://www.customvision.ai) 

### Quickstart

1. Clone the repository
2. Run `pod install`
3. Open the xcworkspace `CVS_ClassifierSample` in Xcode
4. Build and run the sample on your iOS device


### Replacing the sample model with your own object detector
The model provided with the sample recognizes some fruits. To replace it with your own model exported from [Custom Vision Service](https://www.customvision.ai) do the following, and then build and launch the application:

  1. [Create and train](https://docs.microsoft.com/en-us/azure/cognitive-services/custom-vision-service/getting-started-build-a-classifier) a classifer with the Custom Vision Service. You must choose a "compact" domain such as **General (compact)** to be able to export your classifier. If you have an existing classifier you want to export instead, convert the domain in "settings" by clicking on the gear icon at the top right. In setting, choose a "compact" model, Save, and Train your project.

  2. Export your model by going to the Performance tab. Select an iteration trained with a compact domain, an "Export" button will appear. Click on *Export* then *CoreML* then *Export.* Click the *Download* button when it appears. A *.zip* file will download that contains all of these three files:
      - CoreML model (`.mlmodel`)
      - Export manifest file (`cvexport.manifest`).

  3. Drop `model.mlmodel` and `cvexport.manifest` into your Xcode project's Fruit folder.

  4. Build and run.

*This sample has been tested on iPhone devices*


### Compatibility

This latest sample application relies on the new iOS library *Custom Vision inference run-time* (or simply *run-time*) to take care of compatibility. It handles:

- __Version check__: Check the version of the exported model by looking at `cvexport.manifest` (more specifically, look for *ExporterVersion* field) and switch logic depending on model version.

    - __Fowrard compatibility__: It is when model version is newer than run-time's maximum supported model version.
    
        - Major version is greater: Throw exception (supposing model format is unknown)

        - Major version is same but minor version is greater: Still works. Run inference.

    - __Backward compatiblity__: Any newer version of the run-time should be able to handle older model versions.

#### Supported model versions

| Run-time version  | Model version |
|--:                |--             |
| Run-time 1.0.0    | Work with model version 1.x |
|                   | Work with model version 2.x |
|                   | Not work with model version 3.0 or higher |


## Resources
- Link to [CoreML documentation](https://developer.apple.com/documentation/coreml)
- Link Apple WWDC videos, samples, and materials for information on [CoreML](https://developer.apple.com/videos/play/wwdc2017/710) and [Vision Framework](https://developer.apple.com/videos/play/wwdc2017/506/)
- Link to [Custom Vision Service Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/custom-vision-service/home)
