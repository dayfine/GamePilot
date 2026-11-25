(* slot_number_from_roll's thresholds (Pokemon/Pokemon_AdvRng.cpp), as the C++
   writes them. *)

let thresholds ~size ~super_rod =
  match size with
  | 12 -> [ 20; 40; 50; 60; 70; 80; 85; 90; 94; 98; 99 ]
  | 5 when super_rod -> [ 40; 80; 95; 99 ]
  | 5 -> [ 60; 90; 95; 99 ]
  | 3 -> [ 60; 80 ]
  | 2 -> [ 70 ]
  | _ -> []
