let tab_id = "boxes_screen.tab"
let party_id = "boxes_screen.party_title"
let tab : Native_box.t = { x = 130; y = 30; w = 110; h = 36 }
let party_title : Native_box.t = { x = 100; y = 100; w = 240; h = 40 }
let white = Color_count.white 200

let probes ~picture =
  Color_count.probe ~picture ~id:tab_id tab white
  @ Color_count.probe ~picture ~id:party_id party_title white

let fraction = Color_count.share
let min_tab = 0.80
let max_party = 0.05

let shown m =
  match (fraction m tab_id, fraction m party_id) with
  | Some t, Some p -> t > min_tab && p < max_party
  | _ -> false
