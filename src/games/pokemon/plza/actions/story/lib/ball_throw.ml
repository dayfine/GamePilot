type options = {
  lock_on_ms : int;
  aim_ms : int;
  right_scrolls : int;
  scroll_hold_ms : int;
  scroll_release_ms : int;
  after_throw_ms : int;
}

let default =
  {
    lock_on_ms = 0;
    aim_ms = 500;
    right_scrolls = 0;
    scroll_hold_ms = 120;
    scroll_release_ms = 80;
    after_throw_ms = 0;
  }

let aim = [ Wire.ZL; Wire.ZR ]
let hold buttons ms = Wire.press ~hold_ms:ms ~cooldown_ms:0 buttons

let scroll o =
  let direction = if o.right_scrolls >= 0 then Wire.Right else Wire.Left in
  [ hold (direction :: aim) o.scroll_hold_ms; hold aim o.scroll_release_ms ]

let inputs o =
  List.concat
    [
      (if o.lock_on_ms > 0 then [ hold [ Wire.ZL ] o.lock_on_ms ] else []);
      [ hold aim o.aim_ms ];
      List.concat (List.init (abs o.right_scrolls) (fun _ -> scroll o));
      (if o.after_throw_ms > 0 then [ Wire.Wait { wait_ms = o.after_throw_ms } ]
       else []);
    ]

let throw (steps : Steps.game_steps) o = steps.submit_batch (inputs o)
