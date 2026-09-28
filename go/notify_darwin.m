// Thin ObjC bridge to UNUserNotificationCenter. Compiled into the Go binary
// via cgo, so notifications carry this app's own bundle identity with no
// Swift and no Xcode IDE. clang from the CLT is the only Apple toolchain.
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <string.h>

void EyeRestRequestAuth(void) {
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                     completionHandler:^(BOOL granted, NSError *_Nullable error){}];
}

// Returns the UNAuthorizationStatus raw value: 0 notDetermined, 1 denied,
// 2 authorized, 3 provisional, 4 ephemeral, -1 on failure.
int EyeRestAuthStatus(void) {
    __block int status = -1;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [[UNUserNotificationCenter currentNotificationCenter]
        getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *_Nonnull settings) {
            status = (int)settings.authorizationStatus;
            dispatch_semaphore_signal(sem);
        }];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return status;
}

// soundName is a bundle sound file, e.g. "Glass.aiff". NULL or empty falls
// back to the default sound, mirroring resolveSound's fallback.
void EyeRestNotify(const char *title, const char *body, const char *soundName) {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    if (title) {
        content.title = [NSString stringWithUTF8String:title];
    }
    if (body) {
        content.body = [NSString stringWithUTF8String:body];
    }
    if (soundName && strlen(soundName) > 0) {
        content.sound = [UNNotificationSound soundNamed:[NSString stringWithUTF8String:soundName]];
    } else {
        content.sound = [UNNotificationSound defaultSound];
    }
    UNNotificationRequest *req = [UNNotificationRequest
        requestWithIdentifier:[[NSUUID UUID] UUIDString]
                      content:content
                      trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter]
        addNotificationRequest:req
         withCompletionHandler:^(NSError *_Nullable error){}];
}
