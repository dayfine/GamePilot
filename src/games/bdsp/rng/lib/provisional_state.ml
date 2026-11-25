type held = { state : Xorshift128.state; events : int }
type t = { held : held option; failed_solves : int }

let empty = { held = None; failed_solves = 0 }

type step = Keep_collecting | Provisional | Changed | Dropped | Confirmed

let failed provisional ~confirmation_events =
  match provisional.held with
  | None -> (provisional, Keep_collecting)
  | Some _ ->
      let failed_solves = provisional.failed_solves + 1 in
      if failed_solves < confirmation_events then
        ({ provisional with failed_solves }, Keep_collecting)
      else (empty, Dropped)

let solved provisional state ~events =
  match provisional.held with
  | Some held when held.state = state ->
      ({ provisional with failed_solves = 0 }, Confirmed)
  | previous ->
      let step = if previous = None then Provisional else Changed in
      ({ held = Some { state; events }; failed_solves = 0 }, step)

let update provisional solve ~events ~confirmation_events =
  match solve with
  | None -> failed provisional ~confirmation_events
  | Some state -> solved provisional state ~events
