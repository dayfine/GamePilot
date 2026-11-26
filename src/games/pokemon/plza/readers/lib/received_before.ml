type templates = { gift : string option; code : string option }

let none = { gift = None; code = None }
let gift_id = "received_before.gift"
let code_id = "received_before.code"
let slack = 15
let max_score = 0.03

(* Where each template was cut, in the 1080p frame. *)
let gift_cut : Native_box.t = { x = 696; y = 519; w = 522; h = 42 }
let code_cut : Native_box.t = { x = 825; y = 459; w = 270; h = 45 }

let around (b : Native_box.t) : Native_box.t =
  {
    x = b.x - slack;
    y = b.y - slack;
    w = b.w + (2 * slack);
    h = b.h + (2 * slack);
  }

let gift_line = around gift_cut
let code_line = around code_cut

let match_probe ~id template box =
  Wire.template_match_probe ~id ~box ~delivery:Every ~template ()

let probe ~picture ~id box = function
  | None -> []
  | Some template ->
      Option.to_list
        (Option.map (match_probe ~id template)
           (Native_box.probe_box ~picture box))

let probes ~picture t =
  probe ~picture ~id:gift_id gift_line t.gift
  @ probe ~picture ~id:code_id code_line t.code

let score m id =
  match Effects.probe m id with
  | Some (Wire.Template_match { score; _ }) -> Some score
  | Some
      ( Wire.Color_stats _ | Wire.Color_count _ | Wire.Line_shares _
      | Wire.Find _ | Wire.Other _ )
  | None ->
      None

let shows m id =
  match score m id with Some s -> s <= max_score | None -> false

let gift_received m = shows m gift_id
let code_used m = shows m code_id

let describe m =
  let text id =
    Option.fold ~none:"-" ~some:(Printf.sprintf "%.3f") (score m id)
  in
  Printf.sprintf "received before %s, code used %s" (text gift_id)
    (text code_id)
