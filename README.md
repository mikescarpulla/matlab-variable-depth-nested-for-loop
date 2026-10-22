# matlab-variable-depth-nested-for-loop
what the name says - lets you create a for loop with variable levels of nesting and execute commands before, inside, and after the indices update for each nested level.

A MATLAB function that runs a set of nested `for` loops whose **number of levels is decided at run time**. You can run code at each level of the nest, not just in the innermost loop.

Writing nested loops by hand fixes the depth when you write the code. Parameter sweeps often need a depth that depends on the problem, for example sweeping however many physical parameters a model has. This function takes the loop variables and their ranges as vectors and does the nesting for you.

## Quick start

```matlab
% Print every combination of i = 1..2 and j = 0, 0.5, 1
matlab_variable_depth_nested_for_loop({'i','j'}, [1 0], [2 1], [1 0.5])
```

## Syntax

```matlab
matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes)
matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, loop_commands)
matlab_variable_depth_nested_for_loop(..., 'quiet')
```

| Input | Meaning |
|---|---|
| `index_names` | Cell array (or string array) of loop variable names, outermost first, e.g. `{'i','j','k'}`. Each must be a valid MATLAB variable name. |
| `start_lims` | Starting value of each loop variable. |
| `end_lims` | Ending value of each loop variable. |
| `step_sizes` | Step size of each loop variable, or one scalar used for all of them. Only the magnitude is used (see below). |
| `loop_commands` | *(optional)* What to run inside the loops: a function handle or a struct of code blocks (see below). If omitted, the current loop values are printed once per innermost iteration. |
| `'quiet'` | *(optional)* Suppress the step-direction warning. A logical `true` in this position does the same. |

## What runs inside the loops

### A function handle (simple case)

The handle is called once per innermost iteration. It receives a struct whose fields are the loop variables:

```matlab
matlab_variable_depth_nested_for_loop({'x','y'}, [1 1], [3 4], 1, @(v) fprintf('%d\n', v.x*v.y))
```

### A struct of code blocks (code at every level)

The `loop_commands` struct can have a `before` field, an `after` field, or both. Each field is a cell array with one entry per loop level, and each entry is a block of code. A block can be a cell array of command lines (one command per element), a single char or string, or empty for nothing. The function then behaves exactly like writing this out:

```matlab
for i = ...
    <before{1}>
    for j = ...
        <before{2}>
        for k = ...
            <before{3}>
            <after{3}>
        end
        <after{2}>
    end
    <after{1}>
end
```

Example: three loops with code at every level.

```matlab
cmds.before = cell(1, 3);
cmds.before{1} = {'disp(i)', 'disp(j)', 'disp(k)', 's2 = i^2 + j^2 + k^2;', 'disp(s2)'};
cmds.before{2} = {'disp(i+j)', 'disp(j+k)', 'disp(k+i)', 's3 = i^3 + j^3 + k^3;', 'disp(s3)'};
cmds.before{3} = {'s1 = i + j + k;', 'disp(s1)'};
matlab_variable_depth_nested_for_loop({'i','j','k'}, [1 1 1], [5 6 7], 1, cmds)
```

Example: accumulating results with `after` blocks.

```matlab
total = 0;
c.before = {'rowSum = 0;', '', {'total = total + a*b;', 'rowSum = rowSum + b;'}};
c.after = {'fprintf(''a = %g, row sum = %g\n'', a, rowSum)', '', ''};
matlab_variable_depth_nested_for_loop({'a','b','c'}, [3 0 1], [1 1 2], [1 0.25 1], c)
disp(total)
```

Here `a` counts down from 3 to 1 although its step was given as `+1`. The loop runs downward correctly and issues the step-direction warning described below. Add `'quiet'` to suppress it.

How the code blocks behave:

- **They run in your workspace.** Blocks are run with `evalin('caller', ...)`, so they act as if the loops were written in the function or script that made the call. Variables they create, such as `s2` or `total` above, are visible to later blocks and remain after the loops end.
- **The loop variables are real variables.** Before each block runs, `i`, `j`, `k` and so on are set in your workspace by name. Any existing variables with those names are overwritten, as in a normal `for` loop.
- **Inner variables have defined values at outer levels.** When `before{L}` runs, every loop variable inside level `L` holds its start value, so outer blocks can use inner variables even on the first pass. When `after{L}` runs, the inner variables hold their last values.
- **Missing entries are fine.** A missing field, an empty entry, or fewer entries than there are levels all mean that nothing runs there. Misspelled field names are rejected with an error.
- **Errors say where they happened.** An error inside a block is reported with the block (e.g. `loop_commands.before{2}`) and the values of all loop variables at that moment.
- **The loop can't be corrupted by your code.** The loop's own counters live inside the function, so your blocks can use any variable names they like.

## Step direction and the warning

Each loop runs from `start_lims(k)` toward `end_lims(k)`. If the start is greater than the end, the loop counts down. The sign of each step is set automatically to point from start toward end, whatever sign you gave. If the start and end are equal, the loop runs once.

When the sign you gave had to be flipped, a warning is issued. Its first line names the calling function, file and line number (or "the command line"), so you know which call to edit. It then lists the affected variables. Its last lines give the syntax for quiet mode:

```
Warning: Called from my_analysis (my_analysis.m, line 42):
The sign of the step size did not match the direction from the start limit to the end limit, so it was flipped for:
    T: 300 to 100, step used = -50
To suppress this warning, add 'quiet' as the last input:
    matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, 'quiet')
    matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, loop_commands, 'quiet')
```

The warning ID is `matlab_variable_depth_nested_for_loop:stepSignFlipped`, so `warning('off', 'matlab_variable_depth_nested_for_loop:stepSignFlipped')` also turns it off for a session.

## Checks on the code blocks

Two more checks are made before the loops start. Like the step warning, each one names the calling function and doesn't stop the loops from running. Unlike the step warning, `'quiet'` doesn't silence them; use `warning('off', ID)` instead.

**Same code in the innermost `before` and `after`.** In the innermost loop, `before{end}` and `after{end}` run back to back. If both contain the same code, it runs twice in a row on every pass. This is usually a copy-paste slip, so a warning shows the code and asks you to confirm that running it twice is intended. The comparison ignores blank lines, comment lines, surrounding spaces, and a trailing semicolon or comma, so `'disp(x);'` and `' disp(x) '` count as the same. Identical blocks at outer levels aren't flagged, because an inner loop runs between them. Warning ID: `matlab_variable_depth_nested_for_loop:duplicateInnermostBlock`.

```
Warning: Called from my_analysis (my_analysis.m, line 42):
loop_commands.before{2} and loop_commands.after{2} contain the same code. Both belong to the innermost loop (over v) and run back to back, so this code will run twice in a row on every pass:
    s = u + v;
    n = n + 1;
Please confirm that running it twice is what you intended. If not, remove it from one of the two, e.g. loop_commands.after{2} = {};
If it is intended, turn off this warning with: warning('off', 'matlab_variable_depth_nested_for_loop:duplicateInnermostBlock')
```

**No code anywhere.** If `loop_commands` is a struct but every `before` and `after` block is empty (or holds only blank or comment lines), no code would run. The function warns at the start and falls back to the default: the index values are printed once per innermost pass. The warning says how many lines that will be. Warning ID: `matlab_variable_depth_nested_for_loop:noCodeToRun`. Leaving out `loop_commands` altogether also gives the default printing, but without a warning, since that's a deliberate choice.

## Numerical details

Loop values are computed as `start + (n-1)*step` rather than by adding up steps, so round-off does not build up over many iterations. The number of points per loop matches MATLAB's `start:step:end`, including the endpoint when the range is an exact multiple of a non-integer step such as 0.1.

## Limitation: callers that contain nested functions

If the calling function contains nested functions, MATLAB gives it a "static" workspace. In that case `assignin` and `evalin` cannot create new variables in it. The fix is to give every loop variable, and every variable your blocks create, an initial value in the calling function before the call:

```matlab
i = [];
j = [];
s2 = [];
matlab_variable_depth_nested_for_loop({'i','j'}, ..., cmds)
```

The function detects this situation and says so in its error message. Scripts, the command line, and functions without nested functions are not affected.

## Tests

`tests/run_tests.m` runs the test suite and returns the number of failures:

```matlab
nFail = run_tests();   % from inside tests/, or with tests/ on the path
```

Many of the tests compare the function's printed output, line for line, against the same loops written out by hand. The suite covers:

- block placement at every level
- variable persistence in the calling workspace
- step-sign correction and the warning text (caller name from a function and from a script)
- quiet mode
- the duplicate-innermost-block and no-code warnings, including cases that must not warn
- the function-handle mode
- agreement with `start:step:end` for awkward floating-point steps
- control flow such as `if/else` spread across several command lines
- every input-validation error
- the nested-function workspace limitation

The suite runs in MATLAB and in GNU Octave. Two tests depend on MATLAB-only behavior and print `SKIP` under Octave: `string` arrays, and the refusal to `assignin` into a static workspace. Under Octave 8.4 all other tests pass. The warning text for a call made directly at the command line is checked by hand: run `matlab_variable_depth_nested_for_loop({'w'}, 3, 1, 1)` at the prompt, and the warning should begin "Called from the command line".

## Files

```
matlab_variable_depth_nested_for_loop.m    the function
tests/run_tests.m                          test suite
tests/helper_script_caller.m               test helper: calls from a script
tests/helper_nested_ok.m                   test helper: nested-function caller, variables declared
tests/helper_nested_undeclared_loopvar.m   test helper: loop variables not declared
tests/helper_nested_undeclared_blockvar.m  test helper: block variable not declared
```

Files use Windows (CRLF) line endings; `.gitattributes` keeps them that way on checkout.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
