# DoseBuddy Dispenser ESP32-C3 SuperMini

This is the rebuilt dispenser-oriented firmware fork for DoseBuddy. The original sketch in firmware/dosebuddy_esp32_c3_supermini stays as the legacy button-only variant.

Files:

- dosebuddy_dispenser_esp32_c3_supermini.ino - upload this sketch when using the dosing wheel, ULN2003 driver, and 28BYJ-48 stepper motor.

What changed in this fork:

- Adds ULN2003 + 28BYJ-48 stepper control for one-dose wheel dispensing.
- Uses the hardware button to rotate the wheel and dispense one dose during the hour before the scheduled time.
- In the last 10 minutes before the scheduled time, the green LED double-blinks every 5 seconds.
- After a dose window is missed, the red LED and buzzer stay active only for one extra hour.
- During that one-hour missed reminder window, the red LED triple-blinks every 10 seconds, the buzzer pulses for 30 seconds every 5 minutes, and the hardware button still dispenses the missed dose.
- After the missed reminder hour ends, the buzzer stops; if the app enables late dispensing, the red LED triple-blinks every 20 seconds and one missed dispense stays available.
- Tracks remaining doses in Preferences storage and raises a refill-required state after 15 dispenses by default.
- Adds refill and status refresh commands over BLE: refill_dispenser, request_status.
- Replaces the tutorial with wheel-specific states: window_open, dispensing, missed_interval, refill_needed.

BLE contract:

- Service UUID: 8f5a3a62-47ef-4f2b-9b4d-7d716b7b2201
- Control characteristic UUID: 8f5a3a62-47ef-4f2b-9b4d-7d716b7b2202
- Event characteristic UUID: 8f5a3a62-47ef-4f2b-9b4d-7d716b7b2203
- New control commands: refill_dispenser, request_status
- Additional sync_config field: allowLateDispenseAfterMissedHour
- Additional status fields: remainingDoses, dispenserCapacity, refillNeeded, dispenseWindowOpen
- Additional event: refill_needed

Default pin mapping:

- Button: GPIO4
- Green LED: GPIO6
- Red LED: GPIO7
- Buzzer: GPIO5
- ULN2003 IN1: GPIO0
- ULN2003 IN2: GPIO1
- ULN2003 IN3: GPIO2
- ULN2003 IN4: GPIO3
- Battery ADC: disabled by default (-1)

Notes:

- The maximum refill capacity is fixed by `kMaxDispenseCapacity`. The default remains 15 doses.
- The default dose window is 60 minutes. The app sync payload can override it with dispenseWindowMinutes.
- The missed reminder grace period is fixed at 60 minutes via `kMissedAlertGraceMinutes`.
- Missed-dose dispensing uses reduced wheel travel via `kMissedStepperCountsPerDose` so the late recovery dispense does not over-rotate.
- Wheel travel is 3x the original calibration by default: tune `kStepperTravelScaleTenths` in the sketch if you need to fine-tune it.
- The 28BYJ-48 is driven in dual-coil full-step mode for more torque than the old single-coil wave drive.
- The tutorial preview rotates the wheel only partially, not a full dispense rotation.
- Adjust the stepper pins if your ESP32-C3 board wiring differs.
- For best torque, power the ULN2003 board from a stable external 5 V supply, share ground with the ESP32-C3, and raise kStepperPhaseDelayMs slightly if the wheel still skips under load.
