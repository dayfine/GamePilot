type t = { reader : Effects.measurements -> bool; mutable fired : bool }

let create reader = { reader; fired = false }
let see t m = if (not t.fired) && t.reader m then t.fired <- true
let fired t = t.fired
