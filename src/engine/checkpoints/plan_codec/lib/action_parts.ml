module type ACTION_DECODE = sig
  type t

  val names : string list

  val of_plan :
    string -> (where:string -> Json_field.obj -> (t, string) result) option
end

type 'action part =
  | Part :
      (module ACTION_DECODE with type t = 'a) * ('a -> 'action)
      -> 'action part

let read_part (type a) ((module D : ACTION_DECODE with type t = a), into) name =
  Option.map
    (fun read ~where args -> Result.map into (read ~where args))
    (D.of_plan name)

let action_of_plan parts name =
  List.find_map
    (fun (Part (decode, into)) -> read_part (decode, into) name)
    parts

let names (Part ((module D), _)) = D.names

let claimed_twice parts =
  let all = List.concat_map names parts in
  let count name = List.length (List.filter (String.equal name) all) in
  List.fold_left
    (fun twice name ->
      if count name > 1 && not (List.mem name twice) then twice @ [ name ]
      else twice)
    [] all
