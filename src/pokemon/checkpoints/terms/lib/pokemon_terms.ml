module Own_kind = Own_kind
module Postcondition_check = Postcondition_check

module Pose = struct
  include Pose

  type t = declared

  let decode ~where obj =
    Json_field.catch (fun () -> Pose_decode.declared ~where obj)

  (* A zone is decoded and never checked: it holds wherever the player is. *)
  let matches (pose : t) observed =
    match pose with Grid grid -> grid_matches grid observed | Zone _ -> true

  let text = declared_to_string
  let observed_text = observed_to_string
end

module Kind = struct
  type t = Own_kind.t

  let decode name =
    Option.map
      (fun read ~where args -> Json_field.catch (fun () -> read ~where args))
      (Own_kind.decoder name)

  let text = Own_kind.text
end

module Postconditions = struct
  include Postconditions

  type reads = Postcondition_check.observed

  let decode ~where obj =
    Json_field.catch (fun () -> Postcondition_decode.postconditions ~where obj)

  let check = Postcondition_check.check
end

module Saved = struct
  type t = { start : Postcondition_check.start; at : Pose.observed option }

  let items_to_yojson items =
    `Assoc (List.map (fun (i, n) -> (i, `Int n)) items)

  let ( let* ) = Result.bind

  let rec items_read = function
    | [] -> Ok []
    | (item, `Int n) :: rest ->
        let* rest = items_read rest in
        Ok ((item, n) :: rest)
    | (item, _) :: _ -> Error ("start_items: " ^ item ^ " is not a number")

  let items_of_yojson = function
    | `Assoc items -> items_read items
    | _ -> Error "start_items is not an object"

  (* The file: the counts read at the start beside the pose, in one object
     (each item's count an object of counts). [t] nests the counts under
     [start] and the file keeps them flat, so the file is its own record. *)
  type file = {
    start_money : int option;
    start_coins : int option;
    start_items : (string * int) list;
        [@to_yojson items_to_yojson] [@of_yojson items_of_yojson]
    at : Pose.observed option;
  }
  [@@deriving yojson { strict = false }]

  let to_yojson { start = { start_money; start_coins; start_items }; at } =
    file_to_yojson { start_money; start_coins; start_items; at }

  (* A field left out reads as not read: a file kept before the coins and
     items were has only [start_money] and [at]. [@default] would read it too,
     but would also leave the unread fields out of every file written. *)
  let unread =
    [
      ("start_money", `Null);
      ("start_coins", `Null);
      ("start_items", `Assoc []);
      ("at", `Null);
    ]

  let with_unread fields =
    fields
    @ List.filter (fun (name, _) -> not (List.mem_assoc name fields)) unread

  let of_file { start_money; start_coins; start_items; at } =
    { start = { start_money; start_coins; start_items }; at }

  let of_yojson = function
    | `Assoc fields ->
        Result.map of_file (file_of_yojson (`Assoc (with_unread fields)))
    | _ -> Error "what is kept is not an object"
end
