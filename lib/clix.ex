defmodule CLIX do
  @moduledoc """
  A utility-first, composable CLI framework.

  Before we begin, let's first talk about the terminology and conventions used
  in CLIX.

  ## How is CLIX pronounced?

  /klɪks/.

  ## The flow of CLIX

    1. use `CLIX.Spec` to build a spec.
    2. use `CLIX.Parser` to parse argv with the built spec.
    3. use `CLIX.Feedback` to generate user-faced feedbacks with the built spec.

  ## About arguments

  The "arguments" is the abbrev of "command line arguments", which is the main
  thing handled by a CLI framework.

  There are two types of them.

  ### Positional arguments

  In general, positional arguments are the ones which are not prefixed with
  `-` or `--`.

  > Negative number(like `-3`, `-3.14`) is a special case, but CLIX's parser
  > can handle it properly.

  ### Optional arguments

  In general, optional arguments are the ones prefixed with `-` or `--`:

    * POSIX syntax - `-` followed by a single letter indicating an option.
    * GNU-extended syntax - `--` followed by a long name indicating an option.

  > CLIX doesn't support and has no plan to support special prefixes, such as
  > `/` or `+`.

  In practice, optional arguments are often used to implement options. For
  options, there is a further level of classification:

    * options which require subsequent arguments, such as `-o value` or `--option value`.
    * options which don't require subsequent arguments, such as `-o` or `--option`.
      They are commonly referred to as flags, because they represent boolean states.

  > CLIX doesn't explicitly distinguish between flags and options, as a flag is
  > a special type of option.

  #### Option terminator

  The option terminator is `--`. When it is used, all the arguments after it are
  considered as positional arguments.

  ## Conventions

  ### Abbreviations

  To keep code and prose compact, CLIX uses a few abbreviations.

  At the parsing level (used internally by `CLIX.Parser`):

    * `pos_args` - refers to positional arguments
    * `opt_args` - refers to optional arguments

  At the API level (used in `CLIX.Spec`, which CLIX's users interact with):

    * `args` - refers to positional arguments
    * `opts` - refers to options

  And, a bare "arguments", means arguments in the general sense.

  ### The structure of an option

  |                    | option prefix | option string    | option name | option value |
  | ------------------ | ------------- | ---------------- | ----------- | ------------ |
  | `-o <value>`       | `-`           | `o`              | `o`         | `<value>`    |
  | `-o<value>`        | `-`           | `o<value>`       | `o`         | `<value>`    |
  | `--option <value>` | `--`          | `option`         | `option`    | `<value>`    |
  | `--option=<value>` | `--`          | `option=<value>` | `option`    | `<value>`    |

  > This is a convention used in CLIX, not a standard widely accepted.

  """
end
