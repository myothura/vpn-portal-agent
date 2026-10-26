// Strip FLAG_SECURE so scrcpy/screencap can see KBZPay screens.
// FLAG_SECURE = 0x2000 (WindowManager.LayoutParams)
Java.perform(function () {
    var FLAG_SECURE = 0x2000;
    var Window = Java.use("android.view.Window");

    // setFlags(flags, mask)
    Window.setFlags.overload('int', 'int').implementation = function (flags, mask) {
        flags &= ~FLAG_SECURE;
        mask  &= ~FLAG_SECURE;
        return this.setFlags(flags, mask);
    };

    // addFlags(flags)
    Window.addFlags.overload('int').implementation = function (flags) {
        flags &= ~FLAG_SECURE;
        return this.addFlags(flags);
    };

    // LayoutParams direct flag set (some paths set via params)
    try {
        var LP = Java.use("android.view.WindowManager$LayoutParams");
        // nothing to override here reliably; setFlags/addFlags cover it
    } catch (e) {}

    // addPrivateFlags (hidden) — KBZPay CommonUtil.addPrivateFlags uses reflection;
    // FLAG_SECURE is a public flag, so the two overrides above are what matter.
    console.log("[unsecure] FLAG_SECURE strip hooks installed");
});
