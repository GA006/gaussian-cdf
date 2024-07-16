// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/GaussianCDF.sol";

contract DifferentialTests is Test {
    uint256 internal constant EPSILON = 0.00000001 ether; //Error less than 1e-8
    
    int256[3][100000] _inputs;
    int256[100000] _outputs; 
    
    function setUp() public {
        generate();
        load();
    }

    function generate() public {
        string[] memory runJsInputs = new string[](3);
        runJsInputs[0] = "npm";
        runJsInputs[1] = "run";
        runJsInputs[2] = "generate";
        vm.ffi(runJsInputs);
    }

    function load() public {
        string[] memory cmds = new string[](2);
        // Get inputs.
        cmds[0] = "cat";
        cmds[1] = string(abi.encodePacked("js-cdf-generation/data/input"));
        bytes memory result = vm.ffi(cmds);
        _inputs = abi.decode(result, (int256[3][100000]));

        // Get outputs.
        cmds[0] = "cat";
        cmds[1] = string(abi.encodePacked("js-cdf-generation/data/output"));
        result = vm.ffi(cmds);
        _outputs = abi.decode(result, (int256[100000]));
    }

    function testSolVsJsCDF() public view {
        for (uint256 i = 0; i < _inputs.length; ++i) {
            int256[3] memory input = _inputs[i];
            int256 output = _outputs[i];
            int256 computed = GaussianCDF.cdf(input[0], input[1], input[2]);

            assertApproxEqAbs(
                computed,
                output,
                EPSILON,
                vm.toString(i)
            );
        }
    }
}
