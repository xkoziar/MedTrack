# DoseBuddy ESP32-C3 SuperMini

This sketch is designed to match the MedTrack DoseBuddy BLE contract in the app.

Note: this folder remains the legacy button-only variant. The rebuilt dispenser fork with ULN2003 + 28BYJ-48 support lives in firmware/dosebuddy_dispenser_esp32_c3_supermini.

Files:

- `dosebuddy_esp32_c3_supermini.ino` - upload this sketch to the board.

What it implements:

- BLE service UUID `8f5a3a62-47ef-4f2b-9b4d-7d716b7b2201`
- Control characteristic UUID `8f5a3a62-47ef-4f2b-9b4d-7d716b7b2202`
- Event characteristic UUID `8f5a3a62-47ef-4f2b-9b4d-7d716b7b2203`
- Incoming app commands: `sync_config`, `start_demo`, `demo_replay`, `demo_next`, `stop_demo`, `test_signal`
- Outgoing device events: `status`, `button_confirmed`, `already_taken`, `missed_alert`, `demo_step`, `demo_finished`
- Offline confirmation queue replay after the next reconnect and sync

Board setup:

1. Install the `esp32` board package in Arduino IDE or Arduino CLI.
2. Install `ArduinoJson` from Library Manager.
3. Open `dosebuddy_esp32_c3_supermini.ino`.
4. Select an ESP32-C3 board profile that matches your SuperMini. `ESP32C3 Dev Module` is usually fine.
5. Adjust the pin constants at the top of the sketch if your wiring differs.
6. Upload the sketch.

Default pin mapping in the sketch:

- Button: GPIO4
- Green LED: GPIO6
- Red LED: GPIO7
- Buzzer: GPIO5
- Battery ADC: disabled by default (`-1`)

Hardware assumptions:

- The button uses the internal pull-up and is wired to ground when pressed.
- The buzzer is treated as an active buzzer module. If you use a passive piezo buzzer, replace the simple on/off helper with a tone-based implementation.
- Battery measurement is optional. If you wire a divider to an ADC pin, set `batteryAdc` and `kBatteryDividerRatio`.

Behavior notes:

- The sketch keeps advertising the DoseBuddy BLE service and the device name in the main advertisement so the phone app can discover it more reliably.
- It stores the last configuration and any offline confirmations in NVS.
- If the board reboots, it still needs a fresh app sync to restore accurate timekeeping.
- Missed intervals trigger the red alert pattern once per missed slot.
- The tutorial demo is app-controlled: the app starts it, replays the current step, moves to the next step, or finishes it explicitly.
- If the app stops responding during the tutorial, the board leaves demo mode automatically after about 2 minutes and returns to normal operation.
