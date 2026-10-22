function out = helper_nested_undeclared_loopvar()
% HELPER_NESTED_UNDECLARED_LOOPVAR  Used by run_tests. Static workspace
% (contains a nested function) and the loop variables i and j are never
% given values here, so the call should fail with the staticWorkspace hint.
c.before = {'disp(i)', 'disp(j)'};
matlab_variable_depth_nested_for_loop({'i','j'}, [1 1], [1 6], 1, c);
out = getZero();
    function r = getZero()
        r = 0;
    end
end
