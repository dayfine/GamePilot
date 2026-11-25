module Pose = Pose
module Own_kind = Own_kind
module Postconditions = Postconditions
module Postcondition_check = Postcondition_check

type pose = Pose.declared
type observed = Pose.observed
type own_kind = Own_kind.t
type promises = Postconditions.t
type reads = Postcondition_check.observed
type start_reads = Postcondition_check.start

let pose ~where obj =
  Json_field.catch (fun () -> Pose_decode.declared ~where obj)

(* A zone is decoded and never checked: it holds wherever the player is. *)
let matches (pose : pose) observed =
  match pose with Grid grid -> Pose.matches grid observed | Zone _ -> true

let pose_text = Pose.declared_to_string
let observed_text = Pose.observed_to_string
let observed_to_json = Pose.observed_to_json
let observed_of_json = Pose.observed_of_json

let own_kind name =
  Option.map
    (fun read ~where args -> Json_field.catch (fun () -> read ~where args))
    (Own_kind.decoder name)

let own_kind_text = Own_kind.text

let promises ~where obj =
  Json_field.catch (fun () -> Postcondition_decode.postconditions ~where obj)

let no_promises = Postconditions.none
let checked_at_end = Postconditions.checked_at_end
let check = Postcondition_check.check
let promises_text = Postconditions.text
let start_reads_to_json = Postcondition_check.start_to_json
let start_reads_of_json = Postcondition_check.start_of_json
