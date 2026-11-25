(* gamepilot run's flags over the Pokémon grid rules
   (Pokemon_flags.parse): no grid program takes --options, so any is
   refused, not ignored. *)

let case name input expectation = { Table_test.name; input; expectation }

let parsed args () =
  match Pokemon_flags.parse Pokemon_flags.defaults args with
  | Ok f -> "ok: party " ^ f.game.common.party
  | Error e -> "error: " ^ e

let cases =
  [
    case "a grid flag" (parsed [ "--party"; "MEW" ]) "ok: party MEW";
    case "--options: refused, no grid program takes any"
      (parsed [ "--party"; "MEW"; "--options"; "look=5" ])
      "error: --options: this program takes no options";
  ]

let () = Table_test.run "pokemon_flags" cases
