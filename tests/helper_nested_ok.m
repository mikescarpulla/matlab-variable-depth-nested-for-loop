function out = helper_nested_ok()
% HELPER_NESTED_OK  Used by run_tests. This function contains a nested
% function, so its workspace is static. Every variable the loop creates is
% given a value first, so the call works. Expected result: 1*(1+2+...+6) = 21.
i = [];
j = [];
tot = [];
c.before = {'tot = 0;', 'tot = tot + i*j;'};
matlab_variable_depth_nested_for_loop({'i','j'}, [1 1], [1 6], 1, c);
out = getTotal();
    function r = getTotal()
        r = tot;
    end
end
