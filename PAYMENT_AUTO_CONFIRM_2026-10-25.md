# Payment Screenshot Auto-Confirm — KBZPay Probe Findings & Plan

**Date:** 2026-10-25
**Status:** Probe done. a11y auto-nav+extract code written. Architecture pivoted -> server-side redroid emulator (KBZPay login screen reached).

---

## 1. Goal

Payment-screenshot (SS) renewal requests ကို admin က မကိုင်ရသေးရင် auto-confirm လုပ်ဖို့။
KBZPay ငွေဝင် notification ဖမ်းပြီး user တင်တဲ့ SS နဲ့ txn-no တိုက်ကာ အလိုအလျောက် အတည်ပြုတယ်။
SS ထဲက data ကို အခမဲ့ (OCR) ထုတ်တယ်။

---

## 2. Probe Setup (test harness — Myo's phone)

Agent App source: ~/Development/My Documents Data/vpn_agent_app
- Package com.vpnportal.agent, version 3.1.4+19
- Test device (phone): RF8Y70ANM8B (Mac via adb)

### Probe/nav code added (in repo, uncommitted)
- PaymentNotificationListener.kt (marker PAYNOTI_PROBE_V1 -> now also PAYNOTI_A11Y_NAV_V2)
  NotificationListenerService. Logs every noti field -> logcat PAYNOTI + <externalFilesDir>/paynoti.jsonl.
  On "ငွေလက်ခံရရှိပါသည်" from KBZPay, calls PaymentAccessibilityService.navigateNow(postTime).
- PaymentAccessibilityService.kt (marker PAYNOTI_A11Y_NAV_V2, 228 lines)
  AccessibilityService scoped to com.kbzbank.kpaycustomer. Still dumps every KBZPay screen
  (PAYA11Y + paya11y.jsonl). Plus a state machine (IDLE->OPENING->HOME->HISTORY->RECEIPT->DONE)
  that on trigger: launches KBZPay -> taps မှတ်တမ်း -> taps top row -> reads receipt
  tv_field_name/tv_field_value pairs -> writes JSON to payextract.jsonl -> BACK x2.
  Tap via dispatchGesture (coordinate tap on node centre), not node-click. Backend POST = TODO.
- res/xml/payment_a11y_config.xml — added android:canPerformGestures="true".
- AndroidManifest.xml, res/values/payment_a11y_strings.xml — services registered.

### Enable without UI (adb)
    adb shell cmd notification allow_listener com.vpnportal.agent/com.vpnportal.agent.PaymentNotificationListener
    svc=com.vpnportal.agent/com.vpnportal.agent.PaymentAccessibilityService
    cur=$(adb shell settings get secure enabled_accessibility_services | tr -d '\r')
    case ":$cur:" in *":$svc:"*) new=$cur;; *) [ "$cur" = "null" ] || [ -z "$cur" ] && new=$svc || new="$cur:$svc";; esac
    adb shell settings put secure enabled_accessibility_services "$new"
    adb shell settings put secure accessibility_enabled 1

---

## 3. Findings (real 1.00 Ks incoming transfer)

### 3a. KBZPay notification — NOT enough alone
pkg com.kbzbank.kpaycustomer, title "Transaction Message", text/bigText "ငွေလက်ခံရရှိပါသည်",
tag = random FCM id (NOT txn no), postTime ~ receipt time (~1s).
Carries ONLY the time — no amount/sender/txn no. No incoming-money SMS either
(KBZPay SMS = OTP + login/logout only).

### 3b. Accessibility reads EVERYTHING
History list (com.huawei.kbz.ui.activity.RecordActivity) — top row ids:
  tv_trans_type ("ပေးပို့သူ U MYO THURA"), tv_money ("+1.00"), tv_trans_time ("Today 00:29:48");
  direction အဝင်/အထွက်; clickable row container is an ancestor of tv_trans_type.

Receipt screen (tap row, title အသေးစိတ်) — ids tv_field_name / tv_field_value pairs
  + tv_amount, tv_status:
    လုပ်ဆောင်သော အချိန်      25/10/2026 00:29:48
    လုပ်ဆောင်မှုအမှတ် (txn no) 01004315070945425147
    လုပ်ဆောင်မှုအမျိုးအစား   ငွေလွှဲ
    ပေးပို့သူ                U MYO THURA (******0415)
    ငွေပမာဏ                 +1.00 Ks
    မှတ်ချက်                မိသားစုနှင့်မိတ်ဆွေ

Receipt fields = user's E-Receipt SS fields -> txn no matches on both sides.

### 3c. RecordActivity (History) is NOT exported
am start -n .../com.huawei.kbz.ui.activity.RecordActivity -> SecurityException: not exported.
Cannot deep-link History directly. Must open KBZPay launcher then tap မှတ်တမ်း
(present on home as a quick-action text node). On-phone the state machine stalled when KBZPay
was already foreground (singleTop -> no new window event). -> pushed to the emulator approach.

---

## 4. Agreed Architecture

  User SS       -> Backend OCR -> amount + txn no + sender + time
  KBZPay screen -> a11y        -> amount + txn no + sender + time + direction
  Match key     -> Backend     -> txn no (exact match)

Flow: noti "ငွေလက်ခံရရှိပါသည်" = trigger -> open KBZPay History -> a11y reads top row + receipt
-> send fields to backend -> backend OCRs SS, matches txn no, auto-confirms if admin hasn't
handled it. Txn-no exact match kills amount/time collisions.

---

## 5. Open / Next

- Backend POST from PaymentAccessibilityService.emit() (currently file-only).
- Approve via existing RenewalController path — do NOT write new approval logic
  (keeps SINGLE_WRITER / afterCommit intact).
- auto_confirm_after_min setting; claim+approve in one lockForUpdate txn (event used once).
- Rollout: log-only (~1 wk) -> shadow (suggest, admin approves, measure) -> auto-approve (txn-no first).
- Then: Wave Money test (same emulator approach).

## 6. Risks
- KBZPay update may change Burmese labels (ပေးပို့သူ / အဝင် / လုပ်ဆောင်မှုအမှတ်) or device checks
  -> re-verify after updates.
- a11y service death on Xiaomi/Oppo/Vivo (physical) — emulator avoids this.

---

## 7. SERVER-SIDE REDROID EMULATOR — 2026-10-25

Decision: instead of a physical phone, run KBZPay in an always-on Android emulator (redroid/Docker)
on a server, a11y+noti+gesture all on-box. Removes singleTop stall, battery-killer death,
physical-device dependency; one box can serve the fleet.

Host: KL box 72.62.69.97 (Hostinger KVM 8, Ubuntu resolute/kernel 7.0, 31 GB RAM).
NOTE: this box also runs VPPT2 backend (row 220 Reality). redroid is --privileged + loads a host
kernel module — accepted for now; move to a dedicated box if it ever disturbs VPPT2. SSH port 55555.

Stack: redroid 13 (Android 13), x86_64, Docker.
Gate passed: binder is built into this kernel (grep binder /proc/filesystems -> "nodev binder");
modprobe binder_linux exit 0; no KVM/nested-virt needed. ashmem replaced by androidboot.use_memfd=1.
linux-modules-extra not found but not needed (binder built-in).

Container (working form):
    echo 'binder_linux' | sudo tee /etc/modules-load.d/binder.conf
    echo 'options binder_linux devices=binder,hwbinder,vndbinder' | sudo tee /etc/modprobe.d/binder.conf

    docker run -itd --privileged --name kbz1 --restart unless-stopped \
      -v ~/redroid-kbz1:/data -p 5555:5555 \
      redroid/redroid:13.0.0-latest \
      androidboot.use_memfd=1 \
      androidboot.redroid_width=720 androidboot.redroid_height=1280 androidboot.redroid_dpi=320

adb auth: redroid userdebug auto-authorizes; if adb key needed, push host ~/.android/adbkey.pub
into /data/misc/adb/adb_keys (owner 1000:2000) then docker restart.

KBZPay install (split APK, from phone):
Phone APK is a split install (base.apk + split_config.arm64_v8a.apk + split_config.xxhdpi.apk).
base.apk alone -> INSTALL_FAILED_MISSING_SPLIT. Pull all three from phone, scp -P 55555 to box, then:
    adb -s localhost:5555 install-multiple -r ~/kbz-base.apk ~/kbz-arm64.apk ~/kbz-xxhdpi.apk   # Success
arm64 APK runs on x86_64 redroid — redroid 13 image has native-bridge ARM translation;
no NO_MATCHING_ABIS, no .so dlopen crash.
Launcher activity = com.huawei.kbz.ui.base.LaunchActivity (NOT .MainActivity).
(A libbluetooth_jni SIGABRT in crash log is redroid having no BT HAL — unrelated to KBZPay.)

Anti-tamper gate: KBZPay uses RootBeer; it showed a "device rooted" dialog on first launch.
Root cause (logcat RootBeer: checkForRWPaths) was the container's Docker overlayfs mounts, not su.
Resolved on-box so the login screen loads; the specific fix is kept out of this note deliberately.
State reached: "Please Choose Language" (မြန်မာ / English / 中文). Login flow reachable.

Persistence caveat: the on-box fixes are runtime; docker restart / recreate resets them.
Need a post-start hook (entrypoint wrapper / docker exec) to re-apply. Not yet scripted.

### Still to do on emulator
1. Complete KBZPay login — language -> phone-number login -> OTP (emulator has no SIM;
   enter OTP from Myo's phone manually). Session-expiry re-login handling later.
2. Install Agent App (com.vpnportal.agent) in redroid, enable noti + a11y via adb (section 2),
   point it at backend.
3. Re-test the full noti->nav->extract chain inside the emulator (no singleTop stall — we control foreground).
4. Script the post-start hook.
5. Decide: KBZPay session longevity, re-auth cadence, whether MMQR/other screens change the nav path.

### Artifacts
- Box 72.62.69.97: ~/kbz-base.apk ~/kbz-arm64.apk ~/kbz-xxhdpi.apk; screenshots /tmp/kbz*.png;
  redroid data volume ~/redroid-kbz1 (persists install across restart).
- Mac ~/Downloads/: kbz-base.apk kbz-arm64.apk kbz-xxhdpi.apk, kbz*.png.
