#!/usr/bin/env elixir

# Script to run tests and show summary
System.cmd("mix", ["test", "--exclude", "pdf", "--max-failures", "20"], 
  stderr_to_stdout: true,
  into: IO.stream(:stdio, :line))
