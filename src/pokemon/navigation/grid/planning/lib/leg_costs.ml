type t = {
  per_tile : int;
  per_turn : int;
  per_open_stop : int;
  per_open_wild_stop : int;
  per_open_connection_stop : int;
}

let default =
  {
    per_tile = 1;
    per_turn = 2;
    per_open_stop = 8;
    per_open_wild_stop = 0;
    per_open_connection_stop = 0;
  }
