type trigger_kind = Direct_no_pokemon_model | Timeline_single_confirm

type t = {
  id : string;
  template : Static_encounter.template;
  base_stats : Static_encounter.base_stats;
  default_trigger : trigger_kind;
  advances_after_accept : int;
}

let standard_ability = 3
let hidden_ability = 2
let genderless = 255
let always_female = 254
let always_male = 0
let half_female = 127
let legendary_ivs = 3
let default_delay = 84
let ramanas_level = 70
let lake_level = 50
let spear_pillar_level = 47
let arceus_level = 80
let rotom_level = 15

let make ~id ~species ~level ~guaranteed_ivs ~ability_kind ~gender_ratio
    ~base_stats ?(default_trigger = Timeline_single_confirm)
    ?(advances_after_accept = default_delay) () =
  {
    id;
    template =
      {
        species;
        level;
        guaranteed_ivs;
        ability_kind;
        gender_ratio;
        shiny_locked = false;
      };
    base_stats;
    default_trigger;
    advances_after_accept;
  }

let ramanas_single ~id ~species ?(gender_ratio = genderless) base_stats =
  make ~id ~species ~level:ramanas_level ~guaranteed_ivs:legendary_ivs
    ~ability_kind:standard_ability ~gender_ratio ~base_stats ()

let ramanas_hidden ~id ~species base_stats =
  make ~id ~species ~level:ramanas_level ~guaranteed_ivs:legendary_ivs
    ~ability_kind:hidden_ability ~gender_ratio:genderless ~base_stats ()

let kyogre =
  ramanas_single ~id:"kyogre" ~species:"Kyogre"
    { hp = 100; attack = 100; defense = 90; spatk = 150; spdef = 140; speed = 90 }
[@@ocamlformat "disable"]

let groudon =
  ramanas_single ~id:"groudon" ~species:"Groudon"
    { hp = 100; attack = 150; defense = 140; spatk = 100; spdef = 90; speed = 90 }
[@@ocamlformat "disable"]

let sinnoh ~id ~species ~level ?(guaranteed_ivs = legendary_ivs)
    ?(gender_ratio = genderless) ?(default_trigger = Timeline_single_confirm)
    base_stats =
  make ~id ~species ~level ~guaranteed_ivs ~ability_kind:standard_ability
    ~gender_ratio ~base_stats ~default_trigger ()

let all =
  [
    kyogre;
    groudon;
    ramanas_single ~id:"rayquaza" ~species:"Rayquaza"
      { hp = 105; attack = 150; defense = 90; spatk = 150; spdef = 90; speed = 95 };
    ramanas_hidden ~id:"ho-oh" ~species:"Ho-Oh"
      { hp = 106; attack = 130; defense = 90; spatk = 110; spdef = 154; speed = 90 };
    ramanas_hidden ~id:"lugia" ~species:"Lugia"
      { hp = 106; attack = 90; defense = 130; spatk = 90; spdef = 154; speed = 110 };
    ramanas_hidden ~id:"mewtwo" ~species:"Mewtwo"
      { hp = 106; attack = 110; defense = 90; spatk = 154; spdef = 90; speed = 130 };
    ramanas_hidden ~id:"regirock" ~species:"Regirock"
      { hp = 80; attack = 100; defense = 200; spatk = 50; spdef = 100; speed = 50 };
    ramanas_hidden ~id:"regice" ~species:"Regice"
      { hp = 80; attack = 50; defense = 100; spatk = 100; spdef = 200; speed = 50 };
    ramanas_hidden ~id:"registeel" ~species:"Registeel"
      { hp = 80; attack = 75; defense = 150; spatk = 75; spdef = 150; speed = 50 };
    ramanas_hidden ~id:"articuno" ~species:"Articuno"
      { hp = 90; attack = 85; defense = 100; spatk = 95; spdef = 125; speed = 85 };
    ramanas_hidden ~id:"zapdos" ~species:"Zapdos"
      { hp = 90; attack = 90; defense = 85; spatk = 125; spdef = 90; speed = 100 };
    ramanas_hidden ~id:"moltres" ~species:"Moltres"
      { hp = 90; attack = 100; defense = 90; spatk = 125; spdef = 85; speed = 90 };
    ramanas_hidden ~id:"raikou" ~species:"Raikou"
      { hp = 90; attack = 85; defense = 75; spatk = 115; spdef = 100; speed = 115 };
    ramanas_hidden ~id:"entei" ~species:"Entei"
      { hp = 115; attack = 115; defense = 85; spatk = 90; spdef = 75; speed = 100 };
    ramanas_hidden ~id:"suicune" ~species:"Suicune"
      { hp = 100; attack = 75; defense = 115; spatk = 90; spdef = 115; speed = 85 };
    ramanas_single ~id:"latios" ~species:"Latios" ~gender_ratio:always_male
      { hp = 80; attack = 90; defense = 80; spatk = 130; spdef = 110; speed = 110 };
    ramanas_single ~id:"latias" ~species:"Latias" ~gender_ratio:always_female
      { hp = 80; attack = 80; defense = 90; spatk = 110; spdef = 130; speed = 110 };
    sinnoh ~id:"dialga" ~species:"Dialga" ~level:spear_pillar_level
      { hp = 100; attack = 120; defense = 120; spatk = 150; spdef = 100; speed = 90 };
    sinnoh ~id:"palkia" ~species:"Palkia" ~level:spear_pillar_level
      { hp = 90; attack = 120; defense = 100; spatk = 150; spdef = 120; speed = 100 };
    sinnoh ~id:"uxie" ~species:"Uxie" ~level:lake_level
      { hp = 75; attack = 75; defense = 130; spatk = 75; spdef = 130; speed = 95 };
    sinnoh ~id:"azelf" ~species:"Azelf" ~level:lake_level
      { hp = 75; attack = 125; defense = 70; spatk = 125; spdef = 70; speed = 115 };
    sinnoh ~id:"giratina" ~species:"Giratina" ~level:ramanas_level
      { hp = 150; attack = 100; defense = 120; spatk = 100; spdef = 120; speed = 90 };
    sinnoh ~id:"heatran" ~species:"Heatran" ~level:ramanas_level
      ~gender_ratio:half_female
      { hp = 91; attack = 90; defense = 106; spatk = 130; spdef = 106; speed = 77 };
    sinnoh ~id:"regigigas" ~species:"Regigigas" ~level:ramanas_level
      { hp = 110; attack = 160; defense = 110; spatk = 80; spdef = 110; speed = 100 };
    sinnoh ~id:"darkrai" ~species:"Darkrai" ~level:lake_level
      { hp = 70; attack = 90; defense = 90; spatk = 135; spdef = 90; speed = 125 };
    sinnoh ~id:"arceus" ~species:"Arceus" ~level:arceus_level
      { hp = 120; attack = 120; defense = 120; spatk = 120; spdef = 120; speed = 120 };
    sinnoh ~id:"rotom" ~species:"Rotom" ~level:rotom_level ~guaranteed_ivs:0
      ~default_trigger:Direct_no_pokemon_model
      { hp = 50; attack = 50; defense = 77; spatk = 95; spdef = 77; speed = 91 };
  ]
[@@ocamlformat "disable"]

let find id = List.find_opt (fun target -> target.id = id) all
