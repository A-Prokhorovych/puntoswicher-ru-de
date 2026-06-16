#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <ApplicationServices/ApplicationServices.h>
#import <stdint.h>

static const UInt32 kHotKeySignature = 'RUDE';
static const UInt32 kHotKeyID = 1;
static const UInt32 kDefaultHotKeyModifiers = cmdKey | optionKey;
static const UInt32 kDefaultHotKeyCode = 49;
static const char *kAppVersion = "0.6-switch-layout";

static const CGKeyCode kKeyC = 8;
static const CGKeyCode kKeyV = 9;
static const CGKeyCode kKeyDelete = 51;
static const CGKeyCode kKeyCommand = 55;
static const CGKeyCode kKeyLeft = 123;
static const CGKeyCode kKeyRight = 124;

typedef struct {
    UInt32 keyCode;
    UInt32 alternateKeyCode;
    UInt32 modifiers;
    NSString *displayName;
} HotKeyConfig;

static HotKeyConfig gHotKey;
static BOOL gFixInProgress = NO;
static BOOL gPendingHotKey = NO;
static CFMachPortRef gSingleKeyTap = NULL;
static NSMutableString *gLastWord = nil;
static BOOL gDebug = NO;

static void FixPreviousWord(void);
static void ScheduleFixAttempt(int attempt);

static void DebugLog(NSString *format, ...) {
    if (!gDebug) return;

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    fprintf(stderr, "%s\n", message.UTF8String);
    fflush(stderr);
}

static BOOL IsCaretKeyCode(UInt32 keyCode) {
    return keyCode == 50 || keyCode == 10;
}

static BOOL StringIsWordPart(NSString *string) {
    if (!string.length) return NO;

    NSCharacterSet *lettersAndDigits = NSCharacterSet.alphanumericCharacterSet;
    NSCharacterSet *layoutSymbols = [NSCharacterSet characterSetWithCharactersInString:@",.-^+[];'\\/äöüßÄÖÜ"];
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if (![lettersAndDigits characterIsMember:ch] && ![layoutSymbols characterIsMember:ch]) return NO;
    }
    return YES;
}

static void ResetLastWord(void) {
    if (!gLastWord) gLastWord = [NSMutableString string];
    [gLastWord setString:@""];
}

static void TrackTypedKey(CGEventRef event) {
    if (gFixInProgress) return;
    if (!gLastWord) gLastWord = [NSMutableString string];

    CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    if (keyCode == 51) {
        if (gLastWord.length > 0) {
            [gLastWord deleteCharactersInRange:NSMakeRange(gLastWord.length - 1, 1)];
        }
        DebugLog(@"track backspace lastWord='%@'", gLastWord);
        return;
    }

    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags commandLike = kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate;
    if (flags & commandLike) return;

    UniChar chars[8];
    UniCharCount actualLength = 0;
    CGEventKeyboardGetUnicodeString(event, 8, &actualLength, chars);
    if (actualLength == 0) return;

    NSString *text = [NSString stringWithCharacters:chars length:actualLength];
    if (StringIsWordPart(text)) {
        [gLastWord appendString:text];
        DebugLog(@"track text='%@' lastWord='%@'", text, gLastWord);
    } else {
        DebugLog(@"track reset text='%@' lastWord='%@'", text, gLastWord);
        ResetLastWord();
    }
}

static CGEventFlags RequiredEventFlags(UInt32 modifiers) {
    CGEventFlags flags = 0;
    if (modifiers & controlKey) flags |= kCGEventFlagMaskControl;
    if (modifiers & optionKey) flags |= kCGEventFlagMaskAlternate;
    if (modifiers & shiftKey) flags |= kCGEventFlagMaskShift;
    if (modifiers & cmdKey) flags |= kCGEventFlagMaskCommand;
    return flags;
}

static BOOL EventFlagsMatch(CGEventFlags eventFlags, UInt32 modifiers) {
    CGEventFlags required = RequiredEventFlags(modifiers);
    CGEventFlags relevant = kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskShift | kCGEventFlagMaskCommand;
    return (eventFlags & relevant) == required;
}

static BOOL ModifierKeysAreUp(void) {
    CGEventFlags flags = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
    CGEventFlags relevant = kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskShift | kCGEventFlagMaskCommand;
    return (flags & relevant) == 0;
}

static void ScheduleFixWhenModifiersAreUp(void) {
    ScheduleFixAttempt(0);
}

static void ScheduleFixAttempt(int attempt) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        if (!ModifierKeysAreUp() && attempt < 100) {
            ScheduleFixAttempt(attempt + 1);
            return;
        }

        if (!ModifierKeysAreUp()) {
            gPendingHotKey = NO;
            DebugLog(@"fix skipped: modifiers still down");
            return;
        }

        gPendingHotKey = NO;
        DebugLog(@"fix scheduled");
        FixPreviousWord();
    });
}

static NSDictionary<NSString *, NSNumber *> *KeyCodes(void) {
    static NSDictionary<NSString *, NSNumber *> *codes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        codes = @{
            @"a": @0, @"s": @1, @"d": @2, @"f": @3, @"h": @4, @"g": @5, @"z": @6, @"x": @7,
            @"c": @8, @"v": @9, @"b": @11, @"q": @12, @"w": @13, @"e": @14, @"r": @15,
            @"y": @16, @"t": @17, @"1": @18, @"2": @19, @"3": @20, @"4": @21, @"6": @22,
            @"5": @23, @"=": @24, @"9": @25, @"7": @26, @"-": @27, @"8": @28, @"0": @29,
            @"]": @30, @"o": @31, @"u": @32, @"[": @33, @"i": @34, @"p": @35,
            @"return": @36, @"enter": @36, @"l": @37, @"j": @38, @"'": @39, @"k": @40,
            @";": @41, @"\\": @42, @",": @43, @"/": @44, @"n": @45, @"m": @46, @".": @47,
            @"tab": @48, @"space": @49, @"esc": @53, @"escape": @53,
            @"^": @50, @"ё": @50, @"yo": @50, @"grave": @50, @"iso": @10,
            @"f1": @122, @"f2": @120, @"f3": @99, @"f4": @118, @"f5": @96,
            @"f6": @97, @"f7": @98, @"f8": @100, @"f9": @101, @"f10": @109,
            @"f11": @103, @"f12": @111, @"f13": @105, @"f14": @107, @"f15": @113,
            @"f16": @106, @"f17": @64, @"f18": @79, @"f19": @80, @"f20": @90,
            @"pause": @113
        };
    });
    return codes;
}

static HotKeyConfig ParseHotKey(NSString *input) {
    HotKeyConfig config = { kDefaultHotKeyCode, UINT32_MAX, kDefaultHotKeyModifiers, @"Cmd+Option+Space" };
    if (!input.length) return config;

    UInt32 modifiers = 0;
    NSNumber *keyCode = nil;
    NSMutableArray<NSString *> *displayParts = [NSMutableArray array];
    NSArray<NSString *> *parts = [input.lowercaseString componentsSeparatedByString:@"+"];

    for (NSString *rawPart in parts) {
        NSString *part = [rawPart stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (!part.length) continue;

        if ([part isEqualToString:@"cmd"] || [part isEqualToString:@"command"]) {
            modifiers |= cmdKey;
            [displayParts addObject:@"Cmd"];
        } else if ([part isEqualToString:@"opt"] || [part isEqualToString:@"option"] || [part isEqualToString:@"alt"]) {
            modifiers |= optionKey;
            [displayParts addObject:@"Option"];
        } else if ([part isEqualToString:@"ctrl"] || [part isEqualToString:@"control"]) {
            modifiers |= controlKey;
            [displayParts addObject:@"Ctrl"];
        } else if ([part isEqualToString:@"shift"]) {
            modifiers |= shiftKey;
            [displayParts addObject:@"Shift"];
        } else {
            keyCode = KeyCodes()[part];
            NSString *keyName = [part isEqualToString:@"space"] ? @"Space" : part.uppercaseString;
            [displayParts addObject:keyName];
        }
    }

    if (!keyCode) {
        fprintf(stderr, "Неверный хоткей: %s\n", input.UTF8String);
            fprintf(stderr, "Примеры: cmd+^, cmd+ё, ctrl+^, ctrl+ё, ctrl+space\n");
        exit(2);
    }

    config.keyCode = keyCode.unsignedIntValue;
    config.alternateKeyCode = UINT32_MAX;
    NSString *normalizedInput = input.lowercaseString;
    if ([normalizedInput isEqualToString:@"^"] ||
        [normalizedInput isEqualToString:@"ё"] ||
        [normalizedInput isEqualToString:@"yo"] ||
        [normalizedInput hasSuffix:@"+^"] ||
        [normalizedInput hasSuffix:@"+ё"] ||
        [normalizedInput hasSuffix:@"+yo"]) {
        config.alternateKeyCode = 10;
    }
    config.modifiers = modifiers;
    config.displayName = [displayParts componentsJoinedByString:@"+"];
    return config;
}

static NSDictionary<NSString *, NSString *> *TransformTable(void) {
    static NSDictionary<NSString *, NSString *> *table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSArray<NSString *> *> *pairs = @[
            @[@"й", @"q"], @[@"ц", @"w"], @[@"у", @"e"], @[@"к", @"r"], @[@"е", @"t"], @[@"н", @"z"],
            @[@"г", @"u"], @[@"ш", @"i"], @[@"щ", @"o"], @[@"з", @"p"], @[@"х", @"ü"], @[@"ъ", @"+"],
            @[@"ф", @"a"], @[@"ы", @"s"], @[@"в", @"d"], @[@"а", @"f"], @[@"п", @"g"], @[@"р", @"h"],
            @[@"о", @"j"], @[@"л", @"k"], @[@"д", @"l"], @[@"ж", @"ö"], @[@"э", @"ä"],
            @[@"я", @"y"], @[@"ч", @"x"], @[@"с", @"c"], @[@"м", @"v"], @[@"и", @"b"], @[@"т", @"n"],
            @[@"ь", @"m"], @[@"б", @","], @[@"ю", @"."], @[@"ё", @"^"], @[@"-", @"ß"]
        ];

        NSMutableDictionary<NSString *, NSString *> *mapping = [NSMutableDictionary dictionary];
        for (NSArray<NSString *> *pair in pairs) {
            NSString *ru = pair[0];
            NSString *de = pair[1];
            mapping[ru] = de;
            mapping[de] = ru;

            NSString *upperRU = ru.uppercaseString;
            NSString *upperDE = de.uppercaseString;
            if (upperRU.length == 1 && upperDE.length == 1 && ![upperRU isEqualToString:ru] && ![upperDE isEqualToString:de]) {
                mapping[upperRU] = upperDE;
                mapping[upperDE] = upperRU;
            }
        }
        table = [mapping copy];
    });
    return table;
}

static NSString *ConvertString(NSString *input) {
    NSDictionary<NSString *, NSString *> *table = TransformTable();
    NSMutableString *output = [NSMutableString string];

    [input enumerateSubstringsInRange:NSMakeRange(0, input.length)
                              options:NSStringEnumerationByComposedCharacterSequences
                           usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        NSString *replacement = table[substring] ?: substring;
        [output appendString:replacement];
    }];

    return output;
}

static BOOL StringContainsCyrillic(NSString *string) {
    for (NSUInteger index = 0; index < string.length; index++) {
        unichar ch = [string characterAtIndex:index];
        if ((ch >= 0x0400 && ch <= 0x04FF) || (ch >= 0x0500 && ch <= 0x052F)) {
            return YES;
        }
    }
    return NO;
}

static NSString *InputSourceStringProperty(TISInputSourceRef source, CFStringRef key) {
    CFTypeRef value = TISGetInputSourceProperty(source, key);
    if (!value || CFGetTypeID(value) != CFStringGetTypeID()) return nil;
    return (__bridge NSString *)value;
}

static NSArray<NSString *> *InputSourceLanguages(TISInputSourceRef source) {
    CFTypeRef value = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages);
    if (!value || CFGetTypeID(value) != CFArrayGetTypeID()) return @[];
    return (__bridge NSArray<NSString *> *)value;
}

static BOOL InputSourceMatches(TISInputSourceRef source, BOOL wantRussian) {
    NSString *name = InputSourceStringProperty(source, kTISPropertyLocalizedName).lowercaseString ?: @"";
    NSString *sourceID = InputSourceStringProperty(source, kTISPropertyInputSourceID).lowercaseString ?: @"";
    NSArray<NSString *> *languages = InputSourceLanguages(source);

    for (NSString *language in languages) {
        NSString *lower = language.lowercaseString;
        if (wantRussian && [lower hasPrefix:@"ru"]) return YES;
        if (!wantRussian && [lower hasPrefix:@"de"]) return YES;
    }

    if (wantRussian) {
        return [name containsString:@"russian"] ||
               [name containsString:@"рус"] ||
               [sourceID containsString:@"russian"] ||
               [sourceID containsString:@".ru"];
    }

    return [name containsString:@"german"] ||
           [name containsString:@"deutsch"] ||
           [sourceID containsString:@"german"] ||
           [sourceID containsString:@".de"];
}

static void SelectInputSourceForText(NSString *text) {
    BOOL wantRussian = StringContainsCyrillic(text);
    NSDictionary *filter = @{
        (__bridge NSString *)kTISPropertyInputSourceType: (__bridge NSString *)kTISTypeKeyboardLayout
    };
    CFArrayRef sources = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false);
    if (!sources) return;

    CFIndex count = CFArrayGetCount(sources);
    for (CFIndex index = 0; index < count; index++) {
        TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, index);
        if (!InputSourceMatches(source, wantRussian)) continue;

        OSStatus status = TISSelectInputSource(source);
        DebugLog(@"layout select %@ status=%d", wantRussian ? @"ru" : @"de", status);
        CFRelease(sources);
        return;
    }

    DebugLog(@"layout not found for %@", wantRussian ? @"ru" : @"de");
    CFRelease(sources);
}

static void ListInputSources(void) {
    NSDictionary *filter = @{
        (__bridge NSString *)kTISPropertyInputSourceType: (__bridge NSString *)kTISTypeKeyboardLayout
    };
    CFArrayRef sources = TISCreateInputSourceList((__bridge CFDictionaryRef)filter, false);
    if (!sources) return;

    CFIndex count = CFArrayGetCount(sources);
    for (CFIndex index = 0; index < count; index++) {
        TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, index);
        NSString *name = InputSourceStringProperty(source, kTISPropertyLocalizedName) ?: @"";
        NSString *sourceID = InputSourceStringProperty(source, kTISPropertyInputSourceID) ?: @"";
        NSArray<NSString *> *languages = InputSourceLanguages(source);
        printf("%s | %s | %s\n", name.UTF8String, sourceID.UTF8String, [languages componentsJoinedByString:@","].UTF8String);
    }
    CFRelease(sources);
}

static NSString *TrimTypedSingleKeyMarker(NSString *word) {
    if (!word.length) return word;
    if (gHotKey.modifiers != 0 && !IsCaretKeyCode(gHotKey.keyCode) && !IsCaretKeyCode(gHotKey.alternateKeyCode)) return word;

    NSArray<NSString *> *markers = @[@"^", @"ё"];
    for (NSString *marker in markers) {
        if ([word hasSuffix:marker] && word.length > marker.length) {
            return [word substringToIndex:word.length - marker.length];
        }
    }
    return word;
}

static pid_t FrontmostPID(void) {
    NSRunningApplication *app = NSWorkspace.sharedWorkspace.frontmostApplication;
    return app ? app.processIdentifier : 0;
}

static void PostEvent(CGEventRef event, pid_t pid) {
    if (!event) return;
    if (pid > 0) {
        CGEventPostToPid(pid, event);
    } else {
        CGEventPost(kCGHIDEventTap, event);
    }
}

static void PressKey(CGKeyCode keyCode, CGEventFlags flags) {
    pid_t pid = FrontmostPID();
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef down = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef up = CGEventCreateKeyboardEvent(source, keyCode, false);

    if (down) CGEventSetFlags(down, flags);
    if (up) CGEventSetFlags(up, flags);
    PostEvent(down, pid);
    usleep(20000);
    PostEvent(up, pid);
    usleep(60000);

    if (down) CFRelease(down);
    if (up) CFRelease(up);
    if (source) CFRelease(source);
}

static void PressCommandShortcut(CGKeyCode keyCode) {
    pid_t pid = FrontmostPID();
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef commandDown = CGEventCreateKeyboardEvent(source, kKeyCommand, true);
    CGEventRef keyDown = CGEventCreateKeyboardEvent(source, keyCode, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(source, keyCode, false);
    CGEventRef commandUp = CGEventCreateKeyboardEvent(source, kKeyCommand, false);

    if (commandDown) CGEventSetFlags(commandDown, kCGEventFlagMaskCommand);
    if (keyDown) CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
    if (keyUp) CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);

    PostEvent(commandDown, pid);
    usleep(30000);
    PostEvent(keyDown, pid);
    usleep(30000);
    PostEvent(keyUp, pid);
    usleep(30000);
    PostEvent(commandUp, pid);
    usleep(80000);

    if (commandDown) CFRelease(commandDown);
    if (keyDown) CFRelease(keyDown);
    if (keyUp) CFRelease(keyUp);
    if (commandUp) CFRelease(commandUp);
    if (source) CFRelease(source);
}

static void SelectPreviousCharacters(NSUInteger count) {
    for (NSUInteger index = 0; index < count; index++) {
        PressKey(kKeyLeft, kCGEventFlagMaskShift);
    }
}

static void DeletePreviousCharacters(NSUInteger count) {
    for (NSUInteger index = 0; index < count; index++) {
        PressKey(kKeyDelete, 0);
    }
}

static void TypeString(NSString *string) {
    pid_t pid = FrontmostPID();
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);

    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        NSUInteger length = substring.length;
        UniChar buffer[length];
        [substring getCharacters:buffer range:NSMakeRange(0, length)];

        CGEventRef down = CGEventCreateKeyboardEvent(source, 0, true);
        CGEventRef up = CGEventCreateKeyboardEvent(source, 0, false);

        if (down) CGEventKeyboardSetUnicodeString(down, length, buffer);
        if (up) CGEventKeyboardSetUnicodeString(up, length, buffer);
        PostEvent(down, pid);
        usleep(10000);
        PostEvent(up, pid);
        usleep(10000);

        if (down) CFRelease(down);
        if (up) CFRelease(up);
    }];

    if (source) CFRelease(source);
}

static NSDictionary<NSPasteboardType, NSData *> *ClipboardSnapshot(NSPasteboard *pasteboard) {
    NSMutableDictionary<NSPasteboardType, NSData *> *snapshot = [NSMutableDictionary dictionary];
    for (NSPasteboardType type in pasteboard.types) {
        NSData *data = [pasteboard dataForType:type];
        if (data) snapshot[type] = data;
    }
    return [snapshot copy];
}

static void RestoreClipboard(NSPasteboard *pasteboard, NSDictionary<NSPasteboardType, NSData *> *snapshot) {
    [pasteboard clearContents];
    for (NSPasteboardType type in snapshot) {
        [pasteboard setData:snapshot[type] forType:type];
    }
}

static void PasteString(NSString *string, NSDictionary<NSPasteboardType, NSData *> *snapshot) {
    DebugLog(@"paste string='%@'", string);
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:string forType:NSPasteboardTypeString];
    usleep(150000);
    PressCommandShortcut(kKeyV);
    usleep(800000);
    RestoreClipboard(pasteboard, snapshot);
}

static void FixPreviousWord(void) {
    if (gFixInProgress) return;
    gFixInProgress = YES;

    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    NSDictionary<NSPasteboardType, NSData *> *snapshot = ClipboardSnapshot(pasteboard);

    NSString *word = gLastWord.length ? [gLastWord copy] : nil;
    NSUInteger rememberedLength = word.length;
    BOOL usingRememberedWord = rememberedLength > 0;
    DebugLog(@"fix start remembered='%@'", word ?: @"");

    [pasteboard clearContents];
    if (!usingRememberedWord) {
        PressKey(kKeyLeft, kCGEventFlagMaskAlternate | kCGEventFlagMaskShift);
    }

    if (!word.length) {
        PressCommandShortcut(kKeyC);
        for (int attempt = 0; attempt < 30; attempt++) {
            usleep(30000);
            word = [pasteboard stringForType:NSPasteboardTypeString];
            if (word.length) break;
        }
        DebugLog(@"fix fallback clipboard='%@'", word ?: @"");
    }

    if (!word.length) {
        DebugLog(@"fix abort: no word");
        RestoreClipboard(pasteboard, snapshot);
        PressKey(kKeyRight, 0);
        gFixInProgress = NO;
        return;
    }

    word = TrimTypedSingleKeyMarker(word);
    NSString *replacement = ConvertString(word);
    DebugLog(@"fix convert word='%@' replacement='%@'", word, replacement);
    if (![replacement isEqualToString:word]) {
        if (usingRememberedWord) {
            DebugLog(@"delete remembered chars=%lu", (unsigned long)rememberedLength);
            DeletePreviousCharacters(rememberedLength);
        } else {
            DebugLog(@"delete selected word");
            PressKey(kKeyDelete, 0);
        }
        usleep(80000);
        PasteString(replacement, snapshot);
        SelectInputSourceForText(replacement);
        if (!gLastWord) gLastWord = [NSMutableString string];
        [gLastWord setString:replacement];
    } else {
        RestoreClipboard(pasteboard, snapshot);
        PressKey(kKeyRight, 0);
    }
    gFixInProgress = NO;
}

static BOOL CheckAccessibility(void) {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    Boolean trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    if (!trusted) {
        printf("Нужно разрешение Accessibility: System Settings -> Privacy & Security -> Accessibility -> Terminal.\n");
        printf("После разрешения перезапусти эту программу.\n");
    }
    return trusted;
}

static OSStatus HotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    EventHotKeyID hotKeyID;
    GetEventParameter(event,
                      kEventParamDirectObject,
                      typeEventHotKeyID,
                      NULL,
                      sizeof(hotKeyID),
                      NULL,
                      &hotKeyID);

    if (hotKeyID.signature == kHotKeySignature && hotKeyID.id == kHotKeyID) {
        FixPreviousWord();
    }
    return noErr;
}

static CGEventRef SingleKeyHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (gSingleKeyTap) CGEventTapEnable(gSingleKeyTap, true);
        return event;
    }

    if (type != kCGEventKeyDown) return event;

    CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);
    BOOL keyMatches = keyCode == gHotKey.keyCode || keyCode == gHotKey.alternateKeyCode;

    if (keyMatches && EventFlagsMatch(flags, gHotKey.modifiers)) {
        DebugLog(@"hotkey keyCode=%u flags=%llu", keyCode, (unsigned long long)flags);
        if (!gPendingHotKey) {
            gPendingHotKey = YES;
            ScheduleFixWhenModifiersAreUp();
        }
        return NULL;
    }

    TrackTypedKey(event);
    return event;
}

static void InstallSingleKeyTap(HotKeyConfig config) {
    gHotKey = config;
    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap,
                                         kCGHeadInsertEventTap,
                                         0,
                                         mask,
                                         SingleKeyHandler,
                                         NULL);

    if (!tap) {
        fprintf(stderr, "Не удалось включить одиночный хоткей %s.\n", config.displayName.UTF8String);
        fprintf(stderr, "Проверь Accessibility-доступ для Terminal и перезапусти программу.\n");
        exit(1);
    }

    gSingleKeyTap = tap;

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    CFRelease(source);
}

static CGEventRef KeyCodeLogger(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    if (type == kCGEventKeyDown) {
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        CGEventFlags flags = CGEventGetFlags(event);
        printf("keyCode=%u flags=%llu\n", keyCode, (unsigned long long)flags);
        fflush(stdout);
    }
    return event;
}

static void ListenKeyCodes(void) {
    CheckAccessibility();

    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap,
                                         kCGHeadInsertEventTap,
                                         0,
                                         mask,
                                         KeyCodeLogger,
                                         NULL);

    if (!tap) {
        fprintf(stderr, "Не удалось включить диагностику клавиш.\n");
        fprintf(stderr, "Проверь Accessibility-доступ для Terminal и перезапусти программу.\n");
        exit(1);
    }

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
    CFRelease(source);

    printf("Нажми нужную клавишу. Для выхода нажми Ctrl+C.\n");
    [[NSRunLoop mainRunLoop] run];
}

static void InstallHotKey(HotKeyConfig config) {
    if (config.modifiers == 0 || IsCaretKeyCode(config.keyCode) || IsCaretKeyCode(config.alternateKeyCode)) {
        InstallSingleKeyTap(config);
        return;
    }

    EventHotKeyRef hotKeyRef = NULL;
    EventHotKeyID hotKeyID = { kHotKeySignature, kHotKeyID };
    OSStatus status = RegisterEventHotKey(config.keyCode,
                                          config.modifiers,
                                          hotKeyID,
                                          GetApplicationEventTarget(),
                                          0,
                                          &hotKeyRef);
    if (status != noErr) {
        fprintf(stderr, "Не удалось зарегистрировать хоткей %s. Код ошибки: %d\n", config.displayName.UTF8String, status);
        exit(1);
    }

    EventTypeSpec eventType = { kEventClassKeyboard, kEventHotKeyPressed };
    InstallEventHandler(GetApplicationEventTarget(), HotKeyHandler, 1, &eventType, NULL, NULL);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc == 3 && strcmp(argv[1], "--convert") == 0) {
            NSString *input = [NSString stringWithUTF8String:argv[2]];
            printf("%s\n", ConvertString(input).UTF8String);
            return 0;
        }

        if (argc == 3 && strcmp(argv[1], "--type") == 0) {
            if (!CheckAccessibility()) return 1;
            NSString *input = [NSString stringWithUTF8String:argv[2]];
            TypeString(input);
            return 0;
        }

        if (argc == 4 && strcmp(argv[1], "--type-after") == 0) {
            if (!CheckAccessibility()) return 1;
            int delay = atoi(argv[2]);
            if (delay < 0) delay = 0;
            NSString *input = [NSString stringWithUTF8String:argv[3]];
            sleep((unsigned int)delay);
            TypeString(input);
            return 0;
        }

        if (argc == 4 && strcmp(argv[1], "--paste-after") == 0) {
            if (!CheckAccessibility()) return 1;
            int delay = atoi(argv[2]);
            if (delay < 0) delay = 0;
            NSString *input = [NSString stringWithUTF8String:argv[3]];
            NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
            NSDictionary<NSPasteboardType, NSData *> *snapshot = ClipboardSnapshot(pasteboard);
            sleep((unsigned int)delay);
            PasteString(input, snapshot);
            return 0;
        }

        if (argc == 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
            printf("PuntoSwitcher RU-DE\n");
            printf("Запуск: ./.build/puntoswicher-ru-de [--hotkey 'cmd+^']\n");
            printf("Примеры хоткеев: cmd+^, cmd+ё, ctrl+^, ctrl+ё, ctrl+space\n");
            printf("Диагностика клавиш: ./.build/puntoswicher-ru-de --listen-keycodes\n");
            printf("Тест прямого ввода: ./.build/puntoswicher-ru-de --type привет\n");
            printf("Тест с задержкой: ./.build/puntoswicher-ru-de --type-after 3 привет\n");
            printf("Тест вставки: ./.build/puntoswicher-ru-de --paste-after 3 привет\n");
            printf("Список раскладок: ./.build/puntoswicher-ru-de --list-input-sources\n");
            printf("Отладка: ./.build/puntoswicher-ru-de --hotkey 'cmd+^' --debug\n");
            return 0;
        }

        if (argc == 2 && strcmp(argv[1], "--list-input-sources") == 0) {
            ListInputSources();
            return 0;
        }

        if (argc == 2 && strcmp(argv[1], "--listen-keycodes") == 0) {
            ListenKeyCodes();
            return 0;
        }

        HotKeyConfig hotKey = { kDefaultHotKeyCode, UINT32_MAX, kDefaultHotKeyModifiers, @"Cmd+Option+Space" };
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--hotkey") == 0 && i + 1 < argc) {
                hotKey = ParseHotKey([NSString stringWithUTF8String:argv[i + 1]]);
                i++;
            } else if (strcmp(argv[i], "--debug") == 0) {
                gDebug = YES;
            } else {
                fprintf(stderr, "Неизвестный параметр: %s\n", argv[i]);
                fprintf(stderr, "Справка: ./.build/puntoswicher-ru-de --help\n");
                return 2;
            }
        }

        if (!CheckAccessibility()) return 1;
        InstallHotKey(hotKey);

        printf("PuntoSwitcher RU-DE запущен.\n");
        printf("Версия: %s\n", kAppVersion);
        printf("Хоткей: %s. Он исправляет последнее слово слева от курсора.\n", hotKey.displayName.UTF8String);
        printf("Для выхода нажми Ctrl+C в этом терминале.\n");

        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
