open Core.Std
open Async.Std
open Frenetic_NetKAT

module Compiler = Frenetic_NetKAT_Compiler
module Log = Frenetic_Log

type command =
  | Load of string
  | Compile
  | Exit


module Parser = struct
  open MParser

  module Tokens = MParser_RE.Tokens

  (* Use the netkat parser to parse policies *)
  let parse_policy ?(name = "") (pol_str : string) : (policy, string) Result.t =
    try
      Ok (Frenetic_NetKAT_Parser.policy_from_string pol_str)
    with Camlp4.PreCast.Loc.Exc_located (error_loc,x) ->
      Error (sprintf "Error: %s\n%s"
               (Camlp4.PreCast.Loc.to_string error_loc)
               (Exn.to_string x))

  (* Parser for the load command *)
  let load : (command, bytes list) MParser.t =
    Tokens.symbol "load" >>
      many_until any_char eof >>=
      (fun filename -> return (Load (String.of_char_list filename)))

  (* Parser for the compile command *)
  let compile : (command, bytes list) MParser.t =
    Tokens.symbol "exit" >> return Compile

  (* Parser for the exit command *)
  let exit : (command, bytes list) MParser.t =
    Tokens.symbol "exit" >> return Exit

  (* Parser for the exit command *)
  let quit : (command, bytes list) MParser.t =
    Tokens.symbol "quit" >> return Exit

  let command : (command, bytes list) MParser.t =
    load <|>
    quit <|>
    exit

end

(* A reference to the current policy and the associated string. *)
let policy : (policy * string) ref = ref (drop, "drop")

(* A reference to the current automaton and the associated policy. *)
let automaton : (Frenetic_NetKAT_Compiler.automaton * policy) option ref = ref None

let load_file (filename : string) : unit =
  try
    let open In_channel in
    let chan = create filename in
    let policy_string = input_all chan in
    let pol = Parser.parse_policy policy_string in
    close chan;
    match pol with
    | Ok p ->
      policy := (p, policy_string);
      printf " File Contents \n\n";
      printf "%s\n%!" policy_string;
      printf "\n Policy \n\n";
      printf "%s\n%!" (Frenetic_NetKAT_Pretty.string_of_policy p)
    | Error msg -> print_endline msg
  with
  | Sys_error msg -> printf "Load failed: %s\n%!" msg

let compile (pol : policy) : Frenetic_NetKAT_Compiler.automaton =
  Frenetic_NetKAT_Compiler.compile_to_automaton pol

let parse_command (line : string) : command option =
  match (MParser.parse_string Parser.command line []) with
  | Success command -> Some command
  | Failed (msg, e) -> (print_endline msg; None)


let rec repl () : unit Deferred.t =
  printf "autoshell> %!";
  Reader.read_line (Lazy.force Reader.stdin) >>= fun input ->
  let handle line = match line with
    | `Eof -> Shutdown.shutdown 0
    | `Ok line -> match parse_command line with
      | Some (Load filename) -> load_file filename
      | Some Compile ->
        let (pol,_) = !policy in
        automaton := Some (compile pol, pol)
      | Some Exit ->
	print_endline "Goodbye!";
	Shutdown.shutdown 0
      | None -> ()
  in handle input;
  repl ()

let main () : unit =
  Log.set_output [Async.Std.Log.Output.file `Text "frenetic.log"];
  printf "Frenetic Automaton Shell v 1.0\n%!";
  printf "Type `help` for a list of commands\n%!";
  let _ = repl () in
  ()


