#!/usr/bin/env wolframscript
(* Runs one project command: wolframscript -file scripts/project.wls <command> [arguments]. make calls this file.
   The commands are defined in the script package; commands.wl lists them. *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "run.wls"}]]["RunProject"]
