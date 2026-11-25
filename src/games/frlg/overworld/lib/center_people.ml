(* Read off pokefirered data/maps/<Center>/map.json at ce6406d8: each
   object_event but the nurse and the invisible Pokemon Journals, its graphics
   as its name, and its movement type as its motion. *)

open Grid_geometry

type motion =
  | Faces of Direction.t
  | Turns
  | Wanders of { min : Tile_pos.t; max : Tile_pos.t }

type person = {
  name : string;
  at : Tile_pos.t;
  motion : motion;
  script : string option;
  hide_flag : string option;
}

let person ?script ?hide_flag name at motion =
  { name; at; motion; script; hide_flag }

let wanders min max = Wanders { min; max }

let celadon_city =
  [
    person "gentleman" { x = 4; y = 4 } Turns
      ~script:"CeladonCity_PokemonCenter_1F_EventScript_Gentleman";
    person "cooltrainer_f" { x = 10; y = 6 }
      (wanders { x = 8; y = 6 } { x = 12; y = 6 })
      ~script:"CeladonCity_PokemonCenter_1F_EventScript_CooltrainerF";
    person "youngster" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"CeladonCity_PokemonCenter_1F_EventScript_Youngster";
  ]

let cerulean_city =
  [
    person "gentleman" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"CeruleanCity_PokemonCenter_1F_EventScript_Gentleman";
    person "rocker" { x = 5; y = 4 }
      (wanders { x = 4; y = 4 } { x = 6; y = 4 })
      ~script:"CeruleanCity_PokemonCenter_1F_EventScript_Rocker";
    person "youngster" { x = 4; y = 8 }
      (wanders { x = 3; y = 8 } { x = 5; y = 8 })
      ~script:"CeruleanCity_PokemonCenter_1F_EventScript_Youngster";
    person "lass" { x = 3; y = 3 } (Faces Direction.East)
      ~script:"CeruleanCity_PokemonCenter_1F_EventScript_Lass";
  ]

let cinnabar_island =
  [
    person "cooltrainer_f" { x = 2; y = 4 }
      (wanders { x = 1; y = 4 } { x = 3; y = 4 })
      ~script:"CinnabarIsland_PokemonCenter_1F_EventScript_CooltrainerF";
    person "gentleman" { x = 9; y = 7 }
      (wanders { x = 8; y = 6 } { x = 10; y = 8 })
      ~script:"CinnabarIsland_PokemonCenter_1F_EventScript_Gentleman";
    person "youngster" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"CinnabarIsland_PokemonCenter_1F_EventScript_Youngster";
    person "bill" { x = 11; y = 5 } (Faces Direction.South)
      ~script:"CinnabarIsland_PokemonCenter_1F_EventScript_Bill"
      ~hide_flag:"FLAG_HIDE_CINNABAR_POKECENTER_BILL";
  ]

let five_island =
  [
    person "cooltrainer_f" { x = 9; y = 4 } (Faces Direction.North)
      ~script:"FiveIsland_PokemonCenter_1F_EventScript_CooltrainerF";
    person "chef" { x = 4; y = 8 }
      (wanders { x = 3; y = 8 } { x = 5; y = 8 })
      ~script:"FiveIsland_PokemonCenter_1F_EventScript_Chef";
  ]

let four_island =
  [
    person "man" { x = 10; y = 6 }
      (wanders { x = 9; y = 5 } { x = 11; y = 7 })
      ~script:"FourIsland_PokemonCenter_1F_EventScript_Man";
    person "woman_3" { x = 5; y = 5 } Turns
      ~script:"FourIsland_PokemonCenter_1F_EventScript_Woman";
    person "gentleman" { x = 2; y = 2 } (Faces Direction.North)
      ~script:"FourIsland_PokemonCenter_1F_EventScript_Gentleman";
  ]

let fuchsia_city =
  [
    person "man" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"FuchsiaCity_PokemonCenter_1F_EventScript_Man";
    person "cooltrainer_f" { x = 13; y = 3 } (Faces Direction.North)
      ~script:"FuchsiaCity_PokemonCenter_1F_EventScript_CooltrainerF";
    person "youngster" { x = 4; y = 8 }
      (wanders { x = 3; y = 8 } { x = 5; y = 8 })
      ~script:"FuchsiaCity_PokemonCenter_1F_EventScript_Youngster";
  ]

let lavender_town =
  [
    person "gentleman" { x = 9; y = 4 } (Faces Direction.South)
      ~script:"LavenderTown_PokemonCenter_1F_EventScript_Gentleman";
    person "lass" { x = 5; y = 6 }
      (wanders { x = 5; y = 4 } { x = 5; y = 8 })
      ~script:"LavenderTown_PokemonCenter_1F_EventScript_Lass";
    person "youngster" { x = 2; y = 2 }
      (wanders { x = 1; y = 1 } { x = 3; y = 3 })
      ~script:"LavenderTown_PokemonCenter_1F_EventScript_Youngster";
    person "balding_man" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"LavenderTown_PokemonCenter_1F_EventScript_BaldingMan"
      ~hide_flag:"FLAG_HIDE_POSTGAME_GOSSIPERS";
  ]

let pewter_city =
  [
    person "jigglypuff" { x = 2; y = 2 } (Faces Direction.South)
      ~script:"PewterCity_PokemonCenter_1F_EventScript_Jigglypuff";
    person "gentleman" { x = 4; y = 8 } Turns
      ~script:"PewterCity_PokemonCenter_1F_EventScript_Gentleman";
    person "youngster" { x = 1; y = 2 } (Faces Direction.East)
      ~script:"PewterCity_PokemonCenter_1F_EventScript_Youngster";
    person "woman_1" { x = 13; y = 2 } (Faces Direction.South)
      ~script:"MysteryEventClub_EventScript_Woman";
    person "gba_kid" { x = 10; y = 7 } (Faces Direction.East)
      ~script:"PewterCity_PokemonCenter_1F_EventScript_GBAKid1";
    person "gba_kid" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"PewterCity_PokemonCenter_1F_EventScript_GBAKid2";
  ]

let route10 =
  [
    person "gentleman" { x = 9; y = 4 }
      (wanders { x = 8; y = 4 } { x = 10; y = 4 })
      ~script:"Route10_PokemonCenter_1F_EventScript_Gentleman";
    person "fat_man" { x = 2; y = 3 }
      (wanders { x = 1; y = 3 } { x = 3; y = 3 })
      ~script:"Route10_PokemonCenter_1F_EventScript_FatMan";
    person "youngster" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"Route10_PokemonCenter_1F_EventScript_Youngster";
    person "scientist" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"Route10_PokemonCenter_1F_EventScript_Aide";
  ]

let route4 =
  [
    person "balding_man" { x = 1; y = 3 } Turns
      ~script:"Route4_PokemonCenter_1F_EventScript_MagikarpSalesman";
    person "gentleman" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"Route4_PokemonCenter_1F_EventScript_Gentleman";
    person "boy" { x = 5; y = 4 }
      (wanders { x = 4; y = 3 } { x = 6; y = 5 })
      ~script:"Route4_PokemonCenter_1F_EventScript_Boy";
    person "youngster" { x = 14; y = 4 } Turns
      ~script:"Route4_PokemonCenter_1F_EventScript_Youngster";
    person "clipboard" { x = 12; y = 6 } (Faces Direction.South)
      ~script:"Route4_PokemonCenter_1F_EventScript_Newspaper";
  ]

let saffron_city =
  [
    person "gentleman" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"SaffronCity_PokemonCenter_1F_EventScript_Gentleman";
    person "woman_3" { x = 4; y = 4 }
      (wanders { x = 3; y = 3 } { x = 5; y = 5 })
      ~script:"SaffronCity_PokemonCenter_1F_EventScript_Woman";
    person "youngster" { x = 9; y = 6 }
      (wanders { x = 9; y = 5 } { x = 9; y = 7 })
      ~script:"SaffronCity_PokemonCenter_1F_EventScript_Youngster";
  ]

let seven_island =
  [
    person "old_man_1" { x = 11; y = 5 } (Faces Direction.South)
      ~script:"SevenIsland_PokemonCenter_1F_EventScript_OldMan";
    person "sailor" { x = 14; y = 6 } (Faces Direction.West)
      ~script:"SevenIsland_PokemonCenter_1F_EventScript_Sailor";
    person "beauty" { x = 4; y = 4 } (Faces Direction.East)
      ~script:"SevenIsland_PokemonCenter_1F_EventScript_Beauty";
  ]

let six_island =
  [
    person "blue" { x = 5; y = 5 } (Faces Direction.West)
      ~hide_flag:"FLAG_HIDE_SIX_ISLAND_POKECENTER_RIVAL";
    person "hiker" { x = 13; y = 3 } (Faces Direction.North)
      ~script:"SixIsland_PokemonCenter_1F_EventScript_Hiker";
    person "old_man_2" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"SixIsland_PokemonCenter_1F_EventScript_OldMan";
  ]

let three_island =
  [
    person "rocker" { x = 12; y = 2 } (Faces Direction.South)
      ~script:"ThreeIsland_PokemonCenter_1F_EventScript_Rocker";
    person "lass" { x = 3; y = 4 }
      (wanders { x = 2; y = 4 } { x = 4; y = 4 })
      ~script:"ThreeIsland_PokemonCenter_1F_EventScript_Lass";
    person "sailor" { x = 11; y = 5 } (Faces Direction.South)
      ~script:"ThreeIsland_PokemonCenter_1F_EventScript_Sailor";
  ]

let two_island =
  [
    person "gba_kid" { x = 11; y = 5 } (Faces Direction.South)
      ~script:"TwoIsland_PokemonCenter_1F_EventScript_GBAKid";
    person "bug_catcher" { x = 4; y = 4 }
      (wanders { x = 3; y = 4 } { x = 5; y = 4 })
      ~script:"TwoIsland_PokemonCenter_1F_EventScript_BugCatcher";
  ]

let vermilion_city =
  [
    person "man" { x = 4; y = 8 }
      (wanders { x = 3; y = 8 } { x = 5; y = 8 })
      ~script:"VermilionCity_PokemonCenter_1F_EventScript_Man";
    person "hiker" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"VermilionCity_PokemonCenter_1F_EventScript_Hiker";
    person "youngster" { x = 14; y = 4 }
      (wanders { x = 14; y = 3 } { x = 14; y = 5 })
      ~script:"VermilionCity_PokemonCenter_1F_EventScript_Youngster";
    person "cooltrainer_f" { x = 6; y = 4 } (Faces Direction.South)
      ~script:"VermilionCity_PokemonCenter_1F_EventScript_VSSeekerWoman";
  ]

let viridian_city =
  [
    person "gentleman" { x = 12; y = 5 } (Faces Direction.South)
      ~script:"ViridianCity_PokemonCenter_1F_EventScript_Gentleman";
    person "boy" { x = 4; y = 7 } Turns
      ~script:"ViridianCity_PokemonCenter_1F_EventScript_Boy";
    person "youngster" { x = 2; y = 3 }
      (wanders { x = 1; y = 2 } { x = 3; y = 4 })
      ~script:"ViridianCity_PokemonCenter_1F_EventScript_Youngster";
  ]

let table =
  [
    ("CeladonCity", celadon_city);
    ("CeruleanCity", cerulean_city);
    ("CinnabarIsland", cinnabar_island);
    ("FiveIsland", five_island);
    ("FourIsland", four_island);
    ("FuchsiaCity", fuchsia_city);
    ("LavenderTown", lavender_town);
    ("PewterCity", pewter_city);
    ("Route10", route10);
    ("Route4", route4);
    ("SaffronCity", saffron_city);
    ("SevenIsland", seven_island);
    ("SixIsland", six_island);
    ("ThreeIsland", three_island);
    ("TwoIsland", two_island);
    ("VermilionCity", vermilion_city);
    ("ViridianCity", viridian_city);
  ]

let of_town town = Option.value ~default:[] (List.assoc_opt town table)
