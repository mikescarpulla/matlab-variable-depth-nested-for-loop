function matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, varargin)
% matlab_variable_depth_nested_for_loop  Run a nested for loop whose depth is set at run time.
%
%   matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes)
%   matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, loop_commands)
%   matlab_variable_depth_nested_for_loop(..., 'quiet')
%
%   Behaves like writing out (note the innermost loop executes before(3) and
%   after(3) groups of commands - dont accidentally duplicate what you want
%   to actually run.  
%
%       for i = start_lims(1):step_sizes(1):end_lims(1)
%           <before{1}>
%           for j = start_lims(2):step_sizes(2):end_lims(2)
%               <before{2}>
%               for k = start_lims(3):step_sizes(3):end_lims(3)
%                   <before{3}>
%                   <after{3}>
%               end
%               <after{2}>
%           end
%           <after{1}>
%       end
%
%   but for any number of levels. The first variable is the outermost
%   loop and the last variable is the innermost loop.
%
%   Each loop runs from start_lims(k) toward end_lims(k). If
%   start_lims(k) > end_lims(k), the loop counts down. The sign of
%   step_sizes(k) is set automatically to point from the start limit
%   toward the end limit, whatever sign was given. When the given sign
%   had to be flipped, a warning names the calling function and the
%   affected variables. Add 'quiet' to suppress that warning.
%
%   Inputs
%     index_names   - cell array or string array of loop variable names,
%                     e.g. {'i','j','k'}. Each must be a valid variable name.
%     start_lims    - vector of starting values, one per variable
%     end_lims      - vector of ending values, one per variable
%     step_sizes    - vector of step sizes, one per variable, or a scalar
%                     used for every variable. Only the magnitude is used.
%     loop_commands - (optional) what to run inside the loops. Either:
%
%       (a) A function handle, called once per innermost iteration with a
%           struct whose fields are the loop variables, e.g.
%               @(v) disp(v.i + v.j*v.k)
%
%       (b) A struct with fields 'before' and/or 'after'. Each field is a
%           cell array with one entry per loop level. Each entry is a block
%           of code: a cell array of command lines (one command per
%           element), a single char or string, or empty for nothing.
%             before{L} runs at the top of each pass of loop L, before
%                       any loop inside it starts.
%             after{L}  runs at the bottom of each pass of loop L, after
%                       every loop inside it has finished.
%           For the innermost level both run back to back, so either one
%           can hold the innermost body. A missing field means no blocks
%           of that kind.  
%
%  IMPORTANT!!! :  The code runs in the workspace that called this function,
%           exactly as if the loops were written out there. The loop
%           variables are set there by name before each block runs, so
%           the blocks can use them directly, and any variables the blocks
%           create stay there and are visible to later blocks and after
%           the loops end. Existing variables with the same names as the
%           loop variables are overwritten, as in a normal for loop.
%          
% 
% IMPORTANT:  If the calling function contains nested functions, MATLAB
%           will not let new variables be created in its workspace this
%           way; give every loop variable and every variable the blocks
%           create an initial value (e.g. i = []; s2 = [];) before calling.
%
%           When before{L} runs, every loop variable inside level L holds
%           its start value, so outer blocks can read inner variables
%           even on the first pass. When after{L} runs, the inner
%           variables hold their last values.
%
%       If loop_commands is omitted, the current values are printed once
%       per innermost iteration.  (this is the case where you made a loop
%       but didnt have it do anything - so it shows you the index values
%       looping
%
%     'quiet'       - (optional) suppress the step-sign warning. A logical
%                     true in this position does the same thing.
%
%   Checks made before the loops start (each gives a warning that names
%   the calling function, and none of them stops the loops from running):
%     - A step size whose sign had to be flipped (see above).
%     - The innermost level's before and after blocks contain the same
%       code. They run back to back, so that code would run twice in a
%       row on every pass. Lines are compared ignoring blank lines,
%       comments, surrounding spaces and a trailing semicolon or comma.
%       Warning ID: matlab_variable_depth_nested_for_loop:duplicateInnermostBlock
%     - loop_commands is a struct but every block in it is empty, so no
%       code would run anywhere. The default is used instead: the index
%       values are printed once per innermost iteration.
%       Warning ID: matlab_variable_depth_nested_for_loop:noCodeToRun
%   Any of these can be turned off for a session with warning('off', ID).
%
%   Examples
%     matlab_variable_depth_nested_for_loop({'i','j'}, [1 0], [3 1], [1 0.5])
%     matlab_variable_depth_nested_for_loop({'T','x'}, [300 0], [100 1], [50 0.25], 'quiet')
%     matlab_variable_depth_nested_for_loop({'x','y'}, [1 1], [3 4], 1, @(v) fprintf('%d\n', v.x*v.y))
%
%     cmds.before = cell(1, 3);
%     cmds.before{1} = {'disp(i)', 'disp(j)', 'disp(k)', 's2 = i^2 + j^2 + k^2;', 'disp(s2)'};
%     cmds.before{2} = {'disp(i+j)', 'disp(j+k)', 'disp(k+i)', 's3 = i^3 + j^3 + k^3;', 'disp(s3)'};
%     cmds.before{3} = {'s1 = i + j + k;', 'disp(s1)'};
%     matlab_variable_depth_nested_for_loop({'i','j','k'}, [1 1 1], [5 6 7], 1, cmds)

% start of actual function

% ---- parse optional inputs ----
loop_commands = @printVars;
quiet = false;

for a = 1:numel(varargin)
    arg = varargin{a};
    if isa(arg, 'function_handle') || isstruct(arg)
        loop_commands = arg;
    elseif (ischar(arg) || isstring(arg)) && strcmpi(arg, 'quiet')
        quiet = true;
    elseif islogical(arg) && isscalar(arg)
        quiet = arg;
    else
        error('matlab_variable_depth_nested_for_loop:badOption', ...
            'Optional inputs must be a function handle, a loop_commands struct, or ''quiet''.');
    end
end

% ---- shape and check the required inputs ----
index_names = cellstr(index_names);
start_lims = start_lims(:)';
end_lims = end_lims(:)';
step_sizes = step_sizes(:)';
nDepth = numel(index_names);

if isscalar(step_sizes)
    step_sizes = repmat(step_sizes, 1, nDepth);
end

if numel(start_lims) ~= nDepth || numel(end_lims) ~= nDepth || numel(step_sizes) ~= nDepth
    error('matlab_variable_depth_nested_for_loop:sizeMismatch', ...
        'index_names, start_lims, end_lims, and step_sizes must have the same length.');
end

if nDepth == 0
    return
end

badNames = index_names(~cellfun(@isvarname, index_names));
if ~isempty(badNames)
    error('matlab_variable_depth_nested_for_loop:badName', ...
        'Not valid MATLAB variable names: %s', strjoin(badNames, ', '));
end

if any(~isfinite([start_lims end_lims step_sizes]))
    error('matlab_variable_depth_nested_for_loop:nonFinite', ...
        'Limits and step sizes must be finite numbers.');
end

if any(step_sizes == 0)
    error('matlab_variable_depth_nested_for_loop:zeroStep', ...
        'Step sizes must be nonzero.');
end

% ---- decide how loop_commands will be run ----
useBlocks = isstruct(loop_commands);
if useBlocks
    [beforeBlocks, afterBlocks] = parseCommandStruct(loop_commands, nDepth);
end

% ---- point each step from the start limit toward the end limit ----
direction = sign(end_lims - start_lims);
direction(direction == 0) = 1;
flipped = (sign(step_sizes) ~= direction) & (end_lims ~= start_lims);
step_sizes = abs(step_sizes) .* direction;

if any(flipped) && ~quiet
    warnStepFlip(index_names, start_lims, end_lims, step_sizes, flipped);
end

% Number of values each variable takes, like numel(lo:step:hi).
% The small tolerance keeps round-off from dropping the last point
% when the range is an exact multiple of a non-integer step.
nIter = floor((end_lims - start_lims) ./ step_sizes + 1e-9) + 1;

% ---- check the code blocks before starting ----
if useBlocks
    beforeLines = cellfun(@codeLines, beforeBlocks, 'UniformOutput', false);
    afterLines = cellfun(@codeLines, afterBlocks, 'UniformOutput', false);
    if all(cellfun(@isempty, beforeLines)) && all(cellfun(@isempty, afterLines))
        % Nothing to run anywhere: fall back to printing the index values
        warnNoCode(index_names, prod(nIter));
        useBlocks = false;
        loop_commands = @printVars;
    elseif ~isempty(beforeLines{nDepth}) && isequal(beforeLines{nDepth}, afterLines{nDepth})
        % Innermost before and after run back to back: same code twice
        warnDuplicateInnermost(index_names, nDepth, beforeBlocks{nDepth});
    end
end

% ---- odometer-style counter ----
% count(L) is the iteration number (1..nIter(L)) of loop L. Values are
% computed from the count rather than accumulated, so no drift builds up.
% firstChanged is the outermost level whose value changed on this pass;
% every level from there inward is starting a new pass of its loop.
count = ones(1, nDepth);
values = start_lims;
firstChanged = 1;
done = false;

while ~done
    % Update the values of every level that just changed
    for level = firstChanged:nDepth
        values(level) = start_lims(level) + (count(level) - 1) * step_sizes(level);
    end

    if useBlocks
        % Put the loop variables into the caller's workspace
        for level = firstChanged:nDepth
            try
                assignin('caller', index_names{level}, values(level));
            catch ME
                error('matlab_variable_depth_nested_for_loop:staticWorkspace', ...
                    'Could not create loop variable ''%s'' in the calling workspace:\n%s\n%s', ...
                    index_names{level}, ME.message, staticWorkspaceHint());
            end
        end

        % Top of each loop that is starting a new pass, outermost first
        for level = firstChanged:nDepth
            if ~isempty(beforeBlocks{level})
                try
                    evalin('caller', beforeBlocks{level});
                catch ME
                    reportBlockError(ME, 'before', level, index_names, values);
                end
            end
        end
    else
        % Single function handle: call it once per innermost iteration
        vars = struct();
        for level = 1:nDepth
            vars.(index_names{level}) = values(level);
        end
        loop_commands(vars);
    end

    % Bottom of the innermost loop, then advance with carry. Each loop that
    % finishes a pass runs its after block before the next level out moves.
    level = nDepth;
    while level >= 1
        if useBlocks && ~isempty(afterBlocks{level})
            try
                evalin('caller', afterBlocks{level});
            catch ME
                reportBlockError(ME, 'after', level, index_names, values);
            end
        end
        count(level) = count(level) + 1;
        if count(level) <= nIter(level)
            break
        end
        count(level) = 1;
        level = level - 1;
    end

    % Carried past the outermost loop: all iterations finished
    if level == 0
        done = true;
    else
        firstChanged = level;
    end
end

end


function [beforeBlocks, afterBlocks] = parseCommandStruct(cmds, nDepth)
% PARSECOMMANDSTRUCT  Check a loop_commands struct and turn each entry
% into one char block of code (lines joined by newlines, '' if empty).

if ~isscalar(cmds)
    error('matlab_variable_depth_nested_for_loop:badCommands', ...
        'loop_commands must be a single struct, not a struct array.');
end

fields = fieldnames(cmds);
unknown = setdiff(fields, {'before', 'after'});
if ~isempty(unknown)
    error('matlab_variable_depth_nested_for_loop:badCommands', ...
        'loop_commands may only have fields ''before'' and ''after''. Unknown: %s', ...
        strjoin(unknown, ', '));
end

beforeBlocks = repmat({''}, 1, nDepth);
afterBlocks = repmat({''}, 1, nDepth);

if isfield(cmds, 'before')
    beforeBlocks = blocksFromField(cmds.before, 'before', nDepth);
end
if isfield(cmds, 'after')
    afterBlocks = blocksFromField(cmds.after, 'after', nDepth);
end
end


function blocks = blocksFromField(entries, fieldName, nDepth)
% BLOCKSFROMFIELD  Convert one field (before or after) to char blocks.

if isempty(entries)
    blocks = repmat({''}, 1, nDepth);
    return
end

if ~iscell(entries)
    error('matlab_variable_depth_nested_for_loop:badCommands', ...
        'loop_commands.%s must be a cell array with one entry per loop level.', fieldName);
end

if numel(entries) > nDepth
    error('matlab_variable_depth_nested_for_loop:badCommands', ...
        'loop_commands.%s has %d entries but there are only %d loop levels.', ...
        fieldName, numel(entries), nDepth);
end

% Fewer entries than levels: the missing inner levels run nothing
blocks = repmat({''}, 1, nDepth);
newLine = sprintf('\n');

for level = 1:numel(entries)
    entry = entries{level};
    if isempty(entry)
        blocks{level} = '';
    elseif ischar(entry)
        blocks{level} = entry;
    elseif isstring(entry)
        blocks{level} = char(strjoin(entry(:)', newLine));
    elseif iscell(entry)
        lines = cellfun(@char, entry(:)', 'UniformOutput', false);
        blocks{level} = strjoin(lines, newLine);
    else
        error('matlab_variable_depth_nested_for_loop:badCommands', ...
            'loop_commands.%s{%d} must be text, a cell array of command lines, or empty.', ...
            fieldName, level);
    end
end
end


function reportBlockError(ME, blockKind, level, index_names, values)
% REPORTBLOCKERROR  Rethrow an error from a code block with its location.

state = '';
for k = 1:numel(index_names)
    state = [state sprintf('%s = %g  ', index_names{k}, values(k))];
end

hint = '';
if ~isempty(strfind(lower(ME.message), 'static workspace'))
    hint = [sprintf('\n') staticWorkspaceHint()];
end

error('matlab_variable_depth_nested_for_loop:blockError', ...
    'Error in loop_commands.%s{%d} (loop over %s), with %s:\n%s%s', ...
    blockKind, level, index_names{level}, strtrim(state), ME.message, hint);
end


function hint = staticWorkspaceHint()
% STATICWORKSPACEHINT  Explain the nested-function workspace limitation.
hint = sprintf(['The calling function contains nested functions, so MATLAB does not ' ...
    'let new variables be created in its workspace from outside.\n' ...
    'Fix: in the calling function, before this call, give an initial value ' ...
    'to every loop variable and every variable the code blocks create ' ...
    '(e.g. i = []; s2 = [];), or call from a function without nested functions.']);
end


function warnStepFlip(index_names, start_lims, end_lims, step_sizes, flipped)
% WARNSTEPFLIP  Warn that step signs were flipped, naming the caller.

callerText = describeCaller();

details = '';
for k = find(flipped)
    details = [details sprintf('\n    %s: %g to %g, step used = %g', ...
        index_names{k}, start_lims(k), end_lims(k), step_sizes(k))];
end

msg = sprintf(['Called from %s:\n' ...
    'The sign of the step size did not match the direction from the ' ...
    'start limit to the end limit, so it was flipped for:%s\n' ...
    'To suppress this warning, add ''quiet'' as the last input:\n' ...
    '    matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, ''quiet'')\n' ...
    '    matlab_variable_depth_nested_for_loop(index_names, start_lims, end_lims, step_sizes, loop_commands, ''quiet'')'], ...
    callerText, details);

warning('matlab_variable_depth_nested_for_loop:stepSignFlipped', '%s', msg);
end


function warnNoCode(index_names, nTotal)
% WARNNOCODE  Warn that a loop_commands struct holds no code, and say what
% will happen instead.

callerText = describeCaller();

msg = sprintf(['Called from %s:\n' ...
    'loop_commands was given as a struct, but every before and after block ' ...
    'in it is empty, so no code would run anywhere in the loops.\n' ...
    'Using the default instead: the values of %s will be printed to the ' ...
    'screen once per pass of the innermost loop (%d lines).\n' ...
    'To turn off this warning: ' ...
    'warning(''off'', ''matlab_variable_depth_nested_for_loop:noCodeToRun'')'], ...
    callerText, strjoin(index_names, ', '), nTotal);

warning('matlab_variable_depth_nested_for_loop:noCodeToRun', '%s', msg);
end


function warnDuplicateInnermost(index_names, nDepth, block)
% WARNDUPLICATEINNERMOST  Warn that the innermost before and after blocks
% hold the same code, which would then run twice in a row.

callerText = describeCaller();
newLine = sprintf('\n');
indentedCode = ['    ' strrep(block, newLine, [newLine '    '])];

msg = sprintf(['Called from %s:\n' ...
    'loop_commands.before{%d} and loop_commands.after{%d} contain the same code. ' ...
    'Both belong to the innermost loop (over %s) and run back to back, so this ' ...
    'code will run twice in a row on every pass:\n%s\n' ...
    'Please confirm that running it twice is what you intended. If not, remove ' ...
    'it from one of the two, e.g. loop_commands.after{%d} = {};\n' ...
    'If it is intended, turn off this warning with: ' ...
    'warning(''off'', ''matlab_variable_depth_nested_for_loop:duplicateInnermostBlock'')'], ...
    callerText, nDepth, nDepth, index_names{nDepth}, indentedCode, nDepth);

warning('matlab_variable_depth_nested_for_loop:duplicateInnermostBlock', '%s', msg);
end


function lines = codeLines(block)
% CODELINES  Split a block of code into lines for comparison, ignoring
% blank lines, comment lines, surrounding spaces, and a trailing ; or ,
% so that, e.g., 'disp(x);' and ' disp(x) ' count as the same command.

lines = {};
if isempty(block)
    return
end

rawLines = regexp(block, '\r?\n', 'split');
for n = 1:numel(rawLines)
    line = strtrim(rawLines{n});
    line = strtrim(regexprep(line, '[;,\s]+$', ''));
    if ~isempty(line) && line(1) ~= '%'
        lines{end+1} = line;
    end
end
end


function callerText = describeCaller()
% DESCRIBECALLER  Name the function, file and line that called the main
% function, for use at the start of warning messages.
% callStack(1) is this subfunction, (2) the warning subfunction that called
% it, (3) matlab_variable_depth_nested_for_loop, and (4) its caller.

callStack = dbstack;
if numel(callStack) >= 4
    callerText = sprintf('%s (%s, line %d)', callStack(4).name, callStack(4).file, callStack(4).line);
else
    callerText = 'the command line';
end
end


function printVars(vars)
% PRINTVARS  Default loop body: print name = value for each variable.
names = fieldnames(vars);
for n = 1:numel(names)
    fprintf('%s = %g   ', names{n}, vars.(names{n}));
end
fprintf('\n');
end
