# Android Screenshot Protection

To enable screenshot blocking on Android, add this code to your MainActivity.java:

## File: android/app/src/main/java/.../MainActivity.java

```java
package app.lovable.meowmeow;

import android.os.Bundle;
import android.view.WindowManager;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // SECURITY: Enable FLAG_SECURE to prevent screenshots and screen recording
        // This blocks:
        // - Screenshots via power + volume buttons
        // - Screen recording apps
        // - App preview in recent apps (shows black screen)
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        );
    }
}
```

## How to apply:

1. Export project to GitHub
2. Clone the repository locally
3. Run `npx cap add android`
4. Open `android/app/src/main/java/.../MainActivity.java`
5. Add the FLAG_SECURE code as shown above
6. Build with `npx cap build android`

## iOS Notes:

iOS does NOT allow preventing screenshots (Apple policy).
However, you can DETECT when a screenshot is taken:

```swift
// In AppDelegate.swift
NotificationCenter.default.addObserver(
    forName: UIApplication.userDidTakeScreenshotNotification,
    object: nil,
    queue: .main
) { notification in
    // Handle screenshot detection
    // - Log the event
    // - Show a warning
    // - Notify the other user in chat
}
```
