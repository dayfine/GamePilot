(** Read-only discovery of connected Switch controller serial ports and video
    capture devices, plus initial {!Console_config.console} pairing suggestions
    for [gamepilot setup --discover] and the Hub UI.

    Never opens a serial port or capture stream and never sends console input.
*)

type capture_device = {
  index : string;  (** OpenCV / daemon [--capture] index (e.g. ["0"]). *)
  device_id : string;  (** Platform unique device id, or [""] if unknown. *)
  name : string;  (** Human-readable device name (e.g. ["USB Video"]). *)
}
(** One discovered video capture device. *)

val is_serial_device_name : string -> bool
(** Whether a [/dev] entry name looks like a USB Switch controller serial port
    ([cu.usbmodem*], [cu.usbserial*], [ttyUSB*], or [ttyACM*]). *)

val parse_capture_lines : string list -> capture_device list
(** Pure parser for tab-separated [INDEX\tID\tNAME] lines emitted by
    [daemon/tools/list_capture_devices.swift]. *)

val discover_serial_ports : unit -> string list
(** Scans [/dev] on Unix for connected USB serial ports (sorted). Returns [[]]
    on Windows or if [/dev] is unavailable. *)

val discover_capture_devices : unit -> capture_device list
(** Enumerates available capture devices via
    [daemon/tools/list_capture_devices.swift] on macOS or [/dev/video*] on
    Linux. Returns [[]] when unavailable. *)

val suggest_consoles :
  serials:string list ->
  captures:capture_device list ->
  (string * string * string option * string) list
(** Pairs discovered serial ports and capture devices in order into
    [(id, name, serial, capture)] tuples ([console-a] / ["Console A"], ...). *)
