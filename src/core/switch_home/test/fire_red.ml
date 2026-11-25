(* FireRed's tile colour, the same as bin/console_park_command.ml's: its
   orange background and Charizard. *)
let tile : Switch_home.Home_screen.tile_color =
  { min = (200, 40, 0); max = (255, 170, 100) }

(* The GBA picture in the frame, as the daemon's [hello] gives it on the
   switch backend's nso-gba viewport (daemon/src/viewport.cpp). *)
let nso_gba_picture : Wire.box =
  { x = 0.09375; y = 0.00462963; w = 0.8125; h = 0.962963 }
