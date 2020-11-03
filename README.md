# NeosuranceSDK_v3_swift
Neosurance iOS SDK Vers. 3 (swift)

# ![](https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/IOS_logo.svg/32px-IOS_logo.svg.png) iOS - NeosuranceSDK_v3_swift

- Collects info from device sensors and from the hosting app
- Exchanges info with the AI engines
- Sends the push notification
- Displays a landing page
- Displays the list of the purchased policies

## Installation

### iOS

1. NeosuranceSDK_v3_swift is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
target 'NSR SDK SwiftExample' do  
  use_frameworks!

  pod 'NSR_SDK_v3_swift'
end
```

2. Run in the same directory of your Podfile:

```ruby
pod install
```

## Requirements

1. Inside your **info.plist** be sure to have the following permissions:

```xml
<key>NSCameraUsageDescription</key>
<string>use camera...</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Always and when in use...</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Always...</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>When in use...</string>
<key>NSMotionUsageDescription</key>
<string>Motion...</string>
```

## Settings

1. ### setup
	Earlier in your application startup flow (tipically inside the **application didFinishLaunchingWithOptions** method of your application) call the **setup** method using

	**base_url**: provided by us, used only if no *securityDelegate* is configured  
	**code**: the community code provided by us  
	**secret_key**: the community secret key provided by us  
	**dev_mode** *optional*: [0|1] activate the *developer mode*  
		
	```swift	
	let nsr = NSR.getSharedInstance()
    
	nsr.workflowDelegate = WFDelegate()
	
	let settings = NSMutableDictionary()
	settings.setValue(self.config["base_url"], forKey: "base_url")
	settings.setValue(self.config["code"], forKey: "code")
	settings.setValue(self.config["secret_key"], forKey: "secret_key")
	settings.setValue(true, forKey: "dev_mode")
	
	nsr.setup(settings: settings)	
	```
	
...


7. ### Show App
	Is possible to show the list of the purchased policies (*communityApp*) using the **showApp** methods
	
	```swift
	NSR.getSharedInstance().showApp()
	```
	or
	
	```swift
	let params = NSMutableDictionary()
	params.setObject(profiles, forKey: "page" as NSCopying)
	NSR.getSharedInstance().showApp(params: params)	
	```
8. ### showUrl *optional*
	If custom web views are needed the **showUrl** methods can be used
	
	```swift
	NSR.getSharedInstance().showUrl(url: url)
	```
	or
	
	```swift
	let params = NSMutableDictionary()
	params.setObject("true", forKey: "profile" as NSCopying)
	NSR.getSharedInstance().showUrl(url: url, params: params?)	
	```
9. ### Send Event
	The application can send explicit events to the system with **sendEvent** method
	
	```swift
	let params = NSMutableDictionary()
	params.setObject("latitude", forKey: "latitude" as NSCopying)
	params.setObject("longitude", forKey: "longitude" as NSCopying)
	NSR.getSharedInstance().sendEvent(event:"position", payload:payload)
	```
	
10. ### sendAction *optional*
	The application can send tracing information events to the system with **sendAction** method
	
	```swift          
	let nsr = NSR.getSharedInstance()
	nsr.sendAction(action: "read" as! String, code: "xxxx123xxxx" as! String, details: "general condition read" as! String)
	```
	
## Usage (Sample Demo Flow)
1. Tap on button => *"Setup"* (see 1. [setup](#setup))
2. Tap on button => *"registerUser"* (see 5. [registerUser](#register-user))
3. [4.] Tap on button => *"sendEvent: ondemand"* (and/or *"sendEventPush: testpush"*) (see 9. [sendEvent](#send-event))
4. [3.] Tap on button => *"showApp"* In order to show "Purchases List" or "buy a new insurance policy"(just tapping on the title)) (see 7. [showApp](#show-app))	
	
## Author

info@neosurance.eu

## License

NeosuranceSDK is available under the MIT license. See the LICENSE file for more info.

