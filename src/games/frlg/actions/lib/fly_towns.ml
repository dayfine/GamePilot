type town = {
  name : string;
  cell : Grid_maps.Tile_pos.t;
  landing : Story.Pose.observed;
}

let columns = 22
let rows = 15

let town name (cx, cy) map (x, y) =
  {
    name;
    cell = { x = cx; y = cy };
    landing = { at_map = map; at_tile = { x; y }; faces = None };
  }

let kanto =
  [
    town "PalletTown" (4, 11) "PalletTown" (6, 8);
    town "ViridianCity" (4, 8) "ViridianCity" (26, 27);
    town "PewterCity" (4, 4) "PewterCity" (17, 26);
    town "Route4" (8, 3) "Route4" (12, 6);
    town "CeruleanCity" (14, 3) "CeruleanCity" (22, 20);
    town "VermilionCity" (14, 9) "VermilionCity" (15, 7);
    town "Route10" (18, 3) "Route10" (13, 21);
    town "LavenderTown" (18, 6) "LavenderTown" (6, 6);
    town "CeladonCity" (11, 6) "CeladonCity" (48, 12);
    town "SaffronCity" (14, 6) "SaffronCity" (24, 39);
    town "FuchsiaCity" (12, 12) "FuchsiaCity" (25, 32);
    town "CinnabarIsland" (4, 14) "CinnabarIsland" (14, 12);
    town "IndigoPlateau" (2, 3) "IndigoPlateau_Exterior" (11, 7);
  ]

let find name = List.find_opt (fun t -> t.name = name) kanto

(* A cursor step takes 4 frames; the release lets it stop. Up-left to the
   corner: 21 cells at 4 frames is 1.4 s. *)
let cursor_tap_ms = 80
let cursor_release_ms = 170
let to_corner_ms = 3000

let taps button n =
  let tap =
    Wire.Press
      {
        buttons = [ button ];
        hold_ms = cursor_tap_ms;
        cooldown_ms = cursor_release_ms;
      }
  in
  List.init n (fun _ -> tap)

let cursor_presses t =
  Wire.Press
    {
      buttons = [ Wire.Up; Wire.Left ];
      hold_ms = to_corner_ms;
      cooldown_ms = cursor_release_ms;
    }
  :: (taps Wire.Right t.cell.x @ taps Wire.Down t.cell.y)
