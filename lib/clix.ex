defmodule CLIX do
  @moduledoc """
  CLIX (/klɪks/) - A utility-first, composable CLI framework.

  Before we begin, let's first talk about the terminology and conventions used
  in CLIX.

  ## Terminology

  ### Arguments

  The command line is composed of **arguments** — the raw tokens passed to the
  program.

  CLIX classifies them into two kinds:

    * positional arguments
    * named arguments

  #### Positional arguments

  Positional arguments are identified by their position in the command line,
  not by a prefix.

  For example, in `cp src.txt dest.txt`, both `src.txt` and `dest.txt` are
  positional arguments.

  #### Named arguments

  Named arguments are identified by a name prefixed with `-` or `--`,
  not by their position.

  For example, in `docker run --publish 80:80 nginx`, `--publish` is a named
  argument, and `80:80` is the value consumed by the named argument, while
  `run` and `nginx` are positional arguments.

  Two syntaxes are supported:

    * short syntax (POSIX syntax) — a `-` followed by one letter, e.g. `-o`.
    * long syntax (GNU-extended syntax) — a `--` followed by a name, e.g. `--output`.

  > CLIX doesn't support and has no plan to support other prefixes, such as
  > `/` or `+`.

  In practice, named arguments are often used to implement options. Options are
  further classified into two kinds based on whether they consume the value
  immediately following them:

    * options that consume values, such as `-c FILE` or `--config FILE`.
    * options that consume no value, such as `-v` or `--verbose`.
      They are commonly called flags.

  > CLIX treats flags as a special kind of options, without drawing a clear
  > distinction between the two.

  ### args and opts

  The concepts above describe how arguments are identified on the command line.

  When using CLIX, we work with two abstractions:

    * `args` - positional arguments, used as-is.
    * `opts` - options, built on top of named arguments.

  > This mapping exists because named arguments are the mechanism, while options
  > are the intent — you don't think "I need a named argument", you think
  > "I need an option", and named arguments are how that option gets parsed on
  > the command line.

  ## Conventions

  ### Abbreviations

  To keep code and prose compact, CLIX uses a few abbreviations.

  At the API level (used in `CLIX.Spec`, which CLIX's users interact with):

    * `args` - refers to positional arguments
    * `opts` - refers to options

  At the parsing level (used in `CLIX.Parser`, which the maintainers interact with):

    * `pos_args` - collects arguments for positional arguments.
    * `opt_args` - collects arguments for options.

  A bare "arguments" (without qualifier) refers to arguments in the general sense.

  ### The structure of an option

  |                 | option prefix | option string | option name | option value |
  | --------------- | ------------- | ------------- | ----------- | ------------ |
  | `-k <value>`    | `-`           | `k`           | `k`         | `<value>`    |
  | `-k<value>`     | `-`           | `k<value>`    | `k`         | `<value>`    |
  | `--key <value>` | `--`          | `key`         | `key`       | `<value>`    |
  | `--key=<value>` | `--`          | `key=<value>` | `key`       | `<value>`    |

  > This is a convention used in CLIX, not a standard widely accepted.

  ## Usage

  ### The flow of CLIX

    1. use `CLIX.Spec` to build a spec.
    2. use `CLIX.Parser` to parse argv with the built spec.
    3. use `CLIX.Feedback` to generate user-faced feedbacks.

  ## Features

  ### Option terminator

  When the option terminator (`--`) is used, all the arguments after it are
  parsed as positional arguments.

  ## Limitations

  ### Don't support options like `-1`.

  Negative numbers (like `-1`, `-3.14`) are easily confused with options when
  used as arguments.

  Given that modern CLIs rarely use numbers as option names, CLIX chooses not
  to support numbers as option names, in order to reduce complexity.
  """
end
