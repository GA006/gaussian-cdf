// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library ComputeUtils {
    /// @notice Input is equal to -2^{255}
    error Min();

    /// @notice Returns the absolute value of an input.
    /// @param input The value to be converted.
    /// @return output The absolute value of the input.
    function abs(int256 input) public pure returns (uint256 output) {
        if (input == type(int256).min) revert Min();
        if (input < 0) {
            assembly {
                output := add(not(input), 1)
            }
        } else {
            assembly {
                output := input
            }
        }
    }
}
