// types.h — shared type declarations for the dashboard firmware.
//
// These live in a header rather than the .ino because the Arduino IDE
// auto-generates function prototypes and inserts them immediately before
// the first function definition in the sketch. A prototype whose return
// type is declared later in the same file won't compile. Includes are
// always processed first, so anything declared here is in scope.

#pragma once

#include <Arduino.h>

// How the chip came out of sleep.
enum WakeReason
{
  WAKE_BOOT,    // cold boot or reset
  WAKE_TIMER,   // scheduled wake
  WAKE_BUTTON   // ext0 on the button pin
};

// What the button press meant, once its duration was measured.
enum PressKind
{
  PRESS_NONE,   // spurious wake, released before the settle window
  PRESS_SHORT,  // force a re-render of the current dashboard
  PRESS_LONG    // advance to the next dashboard
};

// Outcome of one fetch cycle.
//
// `ok` covers both a fresh image and a 304 — either way the server was
// reached and the sleep interval it returned is trustworthy.
// `unchanged` distinguishes the 304 case, where the panel was left alone.
struct FetchResult
{
  bool     ok           = false;
  bool     unchanged    = false;
  uint32_t sleepSeconds = 0;   // 0 means "caller decides"
  String   message;            // failure detail, for logs and the error screen
};
