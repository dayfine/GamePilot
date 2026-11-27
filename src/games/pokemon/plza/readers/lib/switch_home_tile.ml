let title_template =
  "src/games/pokemon/plza/assets/switch-home-title-legends-za.png"

let title_id = "plza.home_title"
let probes ~title = [ Switch.Home_title.probe title_id title ]
let on_plza_tile m = Switch.Home_title.shows m title_id
let tile_green_blue_min = 120
let tile_red_max = 120
let channel_max = 255

let tile_color : Switch.Home_screen.tile_color =
  {
    min = (0, tile_green_blue_min, tile_green_blue_min);
    max = (tile_red_max, channel_max, channel_max);
  }
